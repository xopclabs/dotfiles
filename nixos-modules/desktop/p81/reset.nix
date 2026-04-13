{ writeShellScriptBin, iproute2, procps, systemd }:

writeShellScriptBin "p81-reset" ''
    set -euo pipefail
    IP=${iproute2}/bin/ip
    PKILL=${procps}/bin/pkill
    SYSTEMCTL=${systemd}/bin/systemctl

    echo 'p81-reset: stopping perimeter81-helper-daemon...'
    "$SYSTEMCTL" stop perimeter81-helper-daemon || true
    sleep 2

    echo 'p81-reset: killing stray Perimeter81 child processes (if any)...'
    # Bubblewrap children may survive briefly; match paths seen in ps/cmdline
    for sig in TERM KILL; do
        "$PKILL" -"$sig" -f '/opt/Perimeter81/binaries/openvpn' 2>/dev/null || true
        "$PKILL" -"$sig" -f 'Perimeter81.*openvpn' 2>/dev/null || true
        "$PKILL" -"$sig" -f 'p81daemonhelper' 2>/dev/null || true
        sleep 0.3
    done

    echo 'p81-reset: flushing routes and removing tun0 (if present)...'
    if "$IP" link show tun0 &>/dev/null; then
        while "$IP" route show dev tun0 2>/dev/null | grep -q .; do
            "$IP" route flush dev tun0 || break
        done
        "$IP" link set tun0 down 2>/dev/null || true
        "$IP" link delete tun0 2>/dev/null || true
    fi

    echo 'p81-reset: starting perimeter81-helper-daemon...'
    "$SYSTEMCTL" start perimeter81-helper-daemon

    echo 'p81-reset: done. Open the Harmony SASE / Perimeter81 app and connect again if needed.'
''
