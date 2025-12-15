#!/bin/bash
#
# Setup Pi-hole + Unbound + Keepalived natively on Orange Pi (Armbian/Debian)
# Run as root on a clean machine
#
# Usage: sudo ./setup.sh
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[-]${NC} $1"; exit 1; }

# Check root
[[ $EUID -ne 0 ]] && error "Run as root: sudo ./setup.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# 1. SYSTEM UPDATE (optional - comment out if already done)
# ============================================================================
# log "Updating system..."
# apt update
# apt upgrade -y

# ============================================================================
# 2. INSTALL UNBOUND
# ============================================================================
log "Installing Unbound..."
apt install -y unbound dns-root-data

# Stop unbound temporarily (pihole installer might conflict)
systemctl stop unbound || true

# Copy unbound config
log "Configuring Unbound..."
cp "$SCRIPT_DIR/etc/unbound/unbound.conf.d/pi-hole.conf" /etc/unbound/unbound.conf.d/pi-hole.conf

# dns-root-data package handles root.key and DNSSEC automatically

# Test config
unbound-checkconf && log "Unbound config OK" || error "Unbound config invalid!"

# ============================================================================
# 3. INSTALL PI-HOLE
# ============================================================================
log "Installing Pi-hole..."

# Create pihole config directory
mkdir -p /etc/pihole

# Create setupVars for unattended install
cat > /etc/pihole/setupVars.conf << 'EOF'
WEBPASSWORD=
PIHOLE_INTERFACE=eth0
QUERY_LOGGING=true
INSTALL_WEB_SERVER=true
INSTALL_WEB_INTERFACE=true
LIGHTTPD_ENABLED=true
CACHE_SIZE=10000
DNS_FQDN_REQUIRED=true
DNS_BOGUS_PRIV=true
DNSMASQ_LISTENING=all
PIHOLE_DNS_1=127.0.0.1#5335
PIHOLE_DNS_2=
DNSSEC=true
REV_SERVER=false
BLOCKING_ENABLED=true
EOF

# Install Pi-hole non-interactively
curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended

# ============================================================================
# 4. INSTALL KEEPALIVED
# ============================================================================
log "Installing Keepalived..."
apt install -y keepalived

# Copy keepalived config
cp "$SCRIPT_DIR/etc/keepalived/keepalived.conf" /etc/keepalived/keepalived.conf

# ============================================================================
# 5. START SERVICES
# ============================================================================
log "Starting services..."

# Start unbound first (pihole depends on it)
systemctl enable unbound
systemctl start unbound

# Restart pihole to pick up unbound
systemctl restart pihole-FTL

# Start keepalived
systemctl enable keepalived
systemctl start keepalived

# ============================================================================
# 6. VERIFY
# ============================================================================
log "Verifying setup..."

echo ""
echo "=== Service Status ==="
systemctl is-active unbound && echo "✓ Unbound: running" || echo "✗ Unbound: not running"
systemctl is-active pihole-FTL && echo "✓ Pi-hole: running" || echo "✗ Pi-hole: not running"
systemctl is-active keepalived && echo "✓ Keepalived: running" || echo "✗ Keepalived: not running"

echo ""
echo "=== DNS Test ==="
dig @127.0.0.1 -p 5335 google.com +short && echo "✓ Unbound responding" || echo "✗ Unbound not responding"
dig @127.0.0.1 google.com +short && echo "✓ Pi-hole responding" || echo "✗ Pi-hole not responding"

echo ""
echo "=== VRRP Status ==="
ip addr show eth0 | grep -q "192.168.254.99" && echo "✓ Virtual IP active (this is MASTER)" || echo "○ Virtual IP not active (this is BACKUP)"

echo ""
log "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Access Pi-hole admin: http://192.168.254.5/admin"
echo "  2. Set Pi-hole password: pihole -a -p"
echo "  3. Test from LAN: dig @192.168.254.5 google.com"
echo "  4. Sync blocklists from NixOS: ./sync-from-nixos.sh"

