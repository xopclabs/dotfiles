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
