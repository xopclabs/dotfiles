# NixOS Dotfiles

Personal NixOS configuration flake for managing multiple hosts: desktops, a homelab (server + NAS), a VPS, and standalone home-manager configurations.

## Hosts overview

| Host | Type | Description |
|------|------|-------------|
| `deck` | NixOS + Home Manager | Steam Deck running Jovian NixOS |
| `laptop` | NixOS + Home Manager | [Not in use] Laptop running basically the same configuration as `deck` |
| `homelab` | NixOS + Home Manager | Self-hosted services (media automation, VPN, DNS) and NAS |
| `vps` | NixOS + Home Manager | [Not in use] Virtual private server |
| `work` | Home Manager only | Non-NixOS machine, managed via standalone home-manager to have the access to the same CLI goodies |

## Simplified directory structure

```
.
├── flake.nix
├── flake.lock

├── hosts/                 # Per-host configurations
│   ├── homelab/
│   │   ├── metadata.nix   # Host-specific metadata values
│   │   ├── user.nix       # Home-manager programs enabling and fine-tune config
│   │   ├── ...
│   │   └── nixos/
│   │       ├── programs.nix        # Same as user.nix but for NixOS modules
│   │       ├── selfhost.nix        # Same as programs.nix but for self-hosted services
│   │       └── ...
│   └── .../
│
├── home-modules/          # Reusable home-manager modules
│   ├── browsers/          # Web-browsers
│   ├── cli/               # Shells, all the CLI utils
│   ├── desktop/           # Desktop/WM related programs
│   ├── editors/           # IDEs
│   ├── terminals/         # Terminal emulators
│   ├── file_managers/     # File Managers: CLI or GUI
│   ├── players/           # Media Players
│   ├── packages/          # Common and optional package sets
│   └── theming/           # Stylix theme management
│
├── nixos-modules/         # Reusable NixOS modules
│   ├── desktop/           # Stuff that is most likely to be used on a desktop PC
│   └── selfhost/          # Self-hosted services

└── secrets/               # SOPS-encrypted secrets
    ├── shared/            # Shared secrets by level of access (personal, selfhost, work)
    └── hosts/             # Per-host secrets
```

## Patterns and structures utilized

### Modular Enable/Configure Pattern

All modules (both home-manager and NixOS) follow the following pattern:

1. Each module defines an enable option using `mkEnableOption` to be enabled on a hosts where it's desired
2. Each module pre-defines some base configuration that's intented to be re-utilized for other hosts
3. Each module exposes via options variables that might need to be changed on different hosts

#### Home-Manager Modules

Modules are defined in `home-modules/` and enabled per-host in `user.nix`:

```nix
# hosts/laptop/user.nix
config.modules = {
    cli = {
        zsh.enable = true;
        tmux = {
            enable = true;
            mouse.enable = true;
        };
        starship = {
            enable = true;
            userBlockColor = "teal";  # Override colr to distinguish hosts by color
        };
    };
    browsers = {
        firefox.enable = true;
        chromium.enable = true;
    };
    terminals.kitty.enable = true;
};
```
All of the browsers modules defined can be enabled but only the `config.modules.browsers.default` value would be set according to priorities set in `home-modules/browsers/default.nix` (works for other modules where `.default` would make sense)

#### NixOS Modules (Desktop)

Desktop modules are defined in `nixos-modules/desktop/` and enabled per-host in `programs.nix`:

```nix
# hosts/laptop/nixos/programs.nix
config.desktop = {
    steam = {
        enable = true;
        hardware.xoneSupport = true;
    };
    wireguard.enable = true;
    flatpak.enable = true;
};
```

### Self-Hosted Services

Self-hosted services are defined in `nixos-modules/selfhost/` and configured per-host in `selfhost.nix`:

```nix
# hosts/homelab/nixos/selfhost.nix
config.homelab = {
    traefik = {
        enable = true;
        dashboardSubdomain = "traefik.vm.local";
    };
    pihole_unbound.enable = true;
    arr-stack = {
        enable = true;
        radarr.subdomain = "movies.vm.local";
        sonarr.subdomain = "tv.vm.local";
        jellyfin.subdomain = "jellyfin.vm.local";
    };
};
```

#### Registering Services with Traefik

Each selfhost module automatically registers itself with Traefik using the `homelab.traefik.routes` option:

```nix
# Inside a selfhost module (e.g., transmission.nix)
homelab.traefik.routes = mkIf config.homelab.traefik.enable [
    {
        name = "transmission";
        subdomain = cfg.subdomain;  # e.g., "torrent.vm.local"
        backendUrl = "http://127.0.0.1:9091";
        # Optional: insecureSkipVerify = true; for self-signed backends
    }
];
```

The `$DOMAIN` suffix is appended automatically from the `traefik` sops secret.

#### Registering Services with Glance Dashboard

Services can register themselves to appear on the Glance dashboard with health monitoring:

```nix
# Inside a selfhost module
homelab.glance.services = mkIf config.homelab.glance.enable [
    {
        title = "Transmission";
        subdomain = cfg.subdomain;
        icon = "si:transmission";  # Simple Icons or MDI icons
        group = "*arr";            # Groups services together
        priority = 1;              # Lower = appears first in group, default is 100
        altStatusCodes = [ 401 403 ];  # Treat auth pages as "up"
    }
];
```

### Metadata

Host-specific data (network config, storage paths, hardware info) is defined in per-host `metadata.nix` files:

```nix
# hosts/homelab/metadata.nix
metadata = {
    user = "homelab";
    hostName = "homelab";
    network = {
        ipv4 = "192.168.254.10";
        defaultGateway = "192.168.254.1";
    };
    selfhost.storage = {
        downloads.mainDir = "/mnt/raid_pool/shared/downloads/torrent";
    };
    hardware = {
        monitors = {
            internal = {
                name = "Valve Corporation ANX7530 U 0x00000001";
                mode = "800x1280@90";
                scale = 1.0;
                transform = "270";
                position = "320,1080";
            };
            external = {
                name = "AOC 22V2WG5 0x000000BF";
                mode = "1920x1080@74.97";
                scale = 1.0;
                position = "0,0";
            };
        };
    };
    
};
```
For now, it only works for two monitors, labeled as `internal` and `external` as I'm only using either a portable machine or a headless one. 

The schema is defined in `hosts/metadata.nix`.

## Useful Commands

See [CHEATSHEET.md](./CHEATSHEET.md) for a comprehensive list of commands, tips, and some caveats.

---

<sub>Disclaimer: *A significant portion of the configuration code was written either by or with a help of a LLM. Obviously, all the code was read and tested - they are mine machines for god's sake...*</sub>

