#!/usr/bin/env bash

set -e


# Function to get active WireGuard interfaces
get_active_interfaces() {
    wg show interfaces 2>/dev/null | tr ' ' '\n' || echo ""
}

# Function to get available WireGuard configs
get_available_configs() {
    ls /etc/wireguard/*.conf 2>/dev/null | sed 's|/etc/wireguard/||' | sed 's|\.conf$||' || echo ""
}

# Function to show usage
usage() {
    echo "Usage: wg-toggle [interface_name]"
    echo ""
    echo "Manages WireGuard interfaces."
    echo "If no interface_name is specified, brings down all active interfaces."
    echo "If interface_name is specified:"
    echo "  - If the interface is up, brings it down"
    echo "  - If the interface is down, brings down all active interfaces then brings up the specified one."
    echo ""
    echo "Available configs:"
    for config in $(get_available_configs); do
        echo "  - $config"
    done
}

# Check if help is requested
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
    exit 0
fi

active_interfaces=$(get_active_interfaces)
available_configs=$(get_available_configs)

if [[ -n "$1" ]]; then
    # Specific interface requested
    interface_name="$1"

    # Validate the interface name
    if ! echo "$available_configs" | grep -q "^${interface_name}$"; then
        echo "Error: Interface '$interface_name' not found"
        echo ""
        echo "Available configs:"
        for config in $available_configs; do
            echo "  - $config"
        done
        exit 1
    fi

    # Check if the requested interface is already active
    if echo "$active_interfaces" | grep -q "^${interface_name}$"; then
        # Interface is already up - just bring it down
        echo "Bringing down: $interface_name"
        wg-quick down "$interface_name"
        echo "✓ $interface_name is now down"
    else
        # Interface is not up - bring down all active interfaces, then bring up the requested one
        if [[ -n "$active_interfaces" ]]; then
            echo "Bringing down all active interfaces..."
            for iface in $active_interfaces; do
                echo "Bringing down: $iface"
                wg-quick down "$iface"
                echo "✓ $iface is now down"
            done
        fi

        # Bring up the requested interface
        echo "Bringing up: $interface_name"
        wg-quick up "$interface_name"
        echo "✓ $interface_name is now up"
    fi
else
    # No specific interface requested - bring down all active interfaces
    if [[ -n "$active_interfaces" ]]; then
        echo "Bringing down all active interfaces..."
        for iface in $active_interfaces; do
            echo "Bringing down: $iface"
            wg-quick down "$iface"
            echo "✓ $iface is now down"
        done
    else
        echo "No active WireGuard interfaces."
    fi
fi
