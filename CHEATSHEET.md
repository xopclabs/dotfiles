# NixOS Cheatsheet

Quick reference for common commands and everything that might be useful to remember.

## System Rebuilds

```bash
# Rebuild and switch from any directory (finds flake by NH_FLAKE env var)
nh os switch

# Update all flake references
nh os switch --update and rebuild

# Useful for quick-tests (well, as quick as it's possible on NixOS and HM...)
nh os switch --offline

# Build on this machine, update the target one via SSH
# --hostname homelab is equivalent to .#homelab from nixos-rebuild
nh os switch --target-host 192.168.254.10 --hostname homelab

# Force building on local machine
nh os switch --max-jobs 0

# Force building on remote machine
nh os switch -- --builders ''

# Rebuild using the nixos-rebuild command
sudo nixos-rebuild switch --flake .#laptop

# Rebuild standalone home-manager
nh home switch
```

## Running software without installing it

```bash
# Run the package immediately (any arguments after first -- will be passed into the package)
nix run nixpkgs#traceroute -- 192.168.254.21

# Temporary add all the packages into current shell
nix shell nixpkgs#traceroute
traceroute 192.168.254.21
```

## Flake Operations

```bash
# Update all flake inputs
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs

# Show flake info
nix flake show

# Check flake for errors
nix flake check
```

## Garbage Collection

```bash
# Remove old generations and garbage collect
nh clean all

# List generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

## Secrets (SOPS)

```bash
# Edit secrets for a host
sops secrets/hosts/laptop.yaml

# Create age key from ed25519 ssh key
nix run nixpkgs#ssh-to-age -- -private-key -i ~/.ssh/id_ed25519 > ~/.config/sops/age/keys.txt
```

## Homelab Services

```bash
# Check service status
systemctl status <service-name>

# View service logs
journalctl -u <service-name> -f 

# Restart a service
sudo systemctl restart <service-name>
```

## ZFS

Pools on homelab: `raid_pool`, `backup_pool`

```bash
# Import a pool (discovers and mounts)
sudo zpool import raid_pool
sudo zpool import backup_pool

# List available pools to import
sudo zpool import

# Export (unmount) a pool
sudo zpool export raid_pool

# Show pool status and health
sudo zpool status
sudo zpool status raid_pool

# List all pools with basic info
sudo zpool list

# List all datasets
zfs list

# List datasets with specific properties
zfs list -o name,used,avail,mountpoint

# Create dataset with specific mountpoint
sudo zfs create -o mountpoint=/mnt/raid_pool/newdata raid_pool/newdata

# Delete a dataset (must be empty or use -r for recursive)
sudo zfs destroy raid_pool/newdata

# Delete dataset and all children
sudo zfs destroy -r raid_pool/shared

# Mount/unmount a dataset manually
sudo zfs mount raid_pool/shared
sudo zfs unmount raid_pool/shared

# Mount all ZFS filesystems
sudo zfs mount -a

# Show dataset properties
zfs get all raid_pool/shared

# Create a snapshot
sudo zfs snapshot raid_pool/shared@backup-2024-01-15

# List snapshots
zfs list -t snapshot

# Rollback to a snapshot
sudo zfs rollback raid_pool/shared@backup-2024-01-15

# Delete a snapshot
sudo zfs destroy raid_pool/shared@backup-2024-01-15
```

## Btrfs

Subvolumes on all hosts: `@` (/), `@var` (/var), `@home` (/home), `@nix` (/nix), `@swap` (/.swap)
Snapshot subvolumes: `@var-snapshots` (/var/.snapshots), `@home-snapshots` (/home/.snapshots)
Extra on laptop/deck: `@home-games`, `@home-steam` (separate to exclude them from snapshots)

```bash
# Show filesystem info (usage, devices)
sudo btrfs filesystem show
sudo btrfs filesystem show /

# Show detailed space usage
sudo btrfs filesystem df /
sudo btrfs filesystem usage /

# List subvolumes
sudo btrfs subvolume list /

# Create a subvolume
sudo btrfs subvolume create /@newsubvol

# Delete a subvolume
sudo btrfs subvolume delete /@newsubvol

# List snapshots (they're just subvolumes)
sudo btrfs subvolume list -s /

# Delete a snapshot
sudo btrfs subvolume delete /home/.snapshots/manual-backup

# Scrub filesystem manually
sudo btrfs scrub start /
sudo btrfs scrub status /

# Defragment a file or directory
sudo btrfs filesystem defragment /path/to/file
sudo btrfs filesystem defragment -r /home

# Show device stats (error counters)
sudo btrfs device stats /

# Snapper (manages snapshots on /var and /home)
snapper -c home list          # List home snapshots
snapper -c root list          # List var snapshots
snapper -c home create --description "before update"
```

## Install on a new host

```bash
# Use install-nixos-anywhere wrapper to copy all the necessary files
install-nixos-anywhere \
        -t root@192.168.254.100 \
        -f ~/dotfiles#laptop \
        -a ~/.ssh/id_ed25519:/home/xopc/.ssh/id_ed25519 \
        -a ~/.ssh/id_ed25519.pub:/home/xopc/.ssh/id_ed25519.pub \
        -a /var/lib/sops/age/keys.txt:/var/lib/sops/age/keys.txt \
        -a ~/dotfiles:/home/xopc/dotfiles -c /home/xopc/dotfiles:1000:100 -c /home/xopc/.ssh:1000:100
```

## Common Caveats

### Rebuilding Issues

- **wg-quick with autostart**: Currently, building a configuration with wg-quick with autostart being UP results in an error
- **mimeapps.list sometimes gives conficts**: Haven't seen this issue for a long while now, but some apps update mimeapps.list imperatively which breaks hm config later

### Secrets

- **Secret not found**: Ensure that both `~/.ssh` key and `/var/lib/sops/age/keys.txt` are present
