# Orange Pi Backup Node

Backup DNS node running natively on Orange Pi (ARMv7/Armbian).

## Services

| Service | Purpose | Port |
|---------|---------|------|
| Pi-hole | DNS ad-blocking | 53/tcp, 53/udp, 80/tcp (web) |
| Unbound | DNS forwarder | 5335 (localhost only) |
| Keepalived | VRRP failover | - |

## Architecture

```
                    ┌─────────────────┐
                    │  Virtual IP     │
                    │ 192.168.254.99  │
                    └────────┬────────┘
                             │ VRRP
         ┌───────────────────┼───────────────────┐
         │                   │                   │
┌────────▼────────┐ ┌────────▼────────┐ ┌────────▼────────┐
│    Homelab      │ │     Laptop      │ │   Orange Pi     │
│  Priority: 150  │ │  Priority: 100  │ │  Priority: 50   │
│    (MASTER)     │ │    (BACKUP)     │ │    (BACKUP)     │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

## Quick Setup

```bash
# 1. Copy this directory to Orange Pi
scp -r orange-pi root@192.168.254.5:/opt/

# 2. Run setup script
ssh root@192.168.254.5
cd /opt/orange-pi
chmod +x setup.sh
./setup.sh

# 3. Set Pi-hole admin password
pihole -a -p

# 4. Sync blocklists from NixOS (run from your machine)
./sync-from-nixos.sh homelab 192.168.254.5
```

## Files

```
orange-pi/
├── setup.sh                              # Main setup script
├── sync-from-nixos.sh                    # Sync Pi-hole data from NixOS
├── etc/
│   ├── unbound/
│   │   └── unbound.conf.d/
│   │       └── pi-hole.conf              # Unbound config for Pi-hole
│   └── keepalived/
│       └── keepalived.conf               # VRRP config
└── README.md
```

## After Setup

### Test DNS

```bash
# From Orange Pi
dig @127.0.0.1 google.com

# From LAN
dig @192.168.254.5 google.com
```

### Check Services

```bash
systemctl status pihole-FTL
systemctl status unbound
systemctl status keepalived
```

### Check VRRP Status

```bash
# See if virtual IP is active
ip addr show eth0 | grep 192.168.254.99

# Watch VRRP traffic
tcpdump -i eth0 vrrp
```

### Pi-hole Admin

- URL: http://192.168.254.5/admin
- Set password: `pihole -a -p`

## Syncing from NixOS

Run periodically from your NixOS host to sync blocklists and secrets:

```bash
# The sync-to-orangepi command is installed on NixOS hosts with pihole_unbound enabled
sync-to-orangepi 192.168.254.5
```

This copies:
- `gravity.db` - blocklists
- `pihole-FTL.db` - query database  
- `custom-hosts` - custom DNS entries (from sops secret)
- `local-domain.conf` - local domain redirect (from sops secret)

## Troubleshooting

### DNS not responding

```bash
# Check services
systemctl status pihole-FTL
systemctl status unbound

# Test unbound directly
dig @127.0.0.1 -p 5335 google.com

# Check pihole logs
pihole -t
```

### Keepalived not failing over

```bash
# Check if VRRP packets are being sent
tcpdump -i eth0 vrrp

# Check keepalived logs
journalctl -u keepalived -f

# Verify config
cat /etc/keepalived/keepalived.conf
```

### Reset Pi-hole

```bash
pihole reconfigure
```

## Maintenance

### Update Pi-hole

```bash
pihole -up
```

### Update blocklists

```bash
pihole -g
```

### View query log

```bash
pihole -t
```
