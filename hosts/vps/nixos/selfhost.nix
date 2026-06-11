{ config, lib, inputs, ... }:

{
    imports = [ 
        ../../../nixos-modules/selfhost/default.nix
    ];
    
    config.homelab = {
        # Essentials
        fail2ban = {
            enable = true;
        };

        traefik = {
            enable = true;
            dashboardSubdomain = "traefik.vps.local";
            certificateDomains = [
                {
                    # Public services
                    main = "*.$DOMAIN";
                    sans = [ "$DOMAIN" ];
                }
                {
                    # VPS local network services
                    main = "*.vps.local.$DOMAIN";
                    sans = [ "vps.local.$DOMAIN" ];
                }
            ];
        };
        pihole_unbound = {
            enable = true;
            pihole = {
                firewall = {
                    dns = false;
                    dhcp = false;
                    webserver = false;
                };
                subdomain = "pihole.vps.local";
            };
        };

        vaultwarden = {
            enable = true;
            subdomain = "vaultwarden";
            backup = {
                enable = true;
                repo = "og0k9udz@og0k9udz.repo.borgbase.com:repo";
            };
        };

        ntfy = {
            enable = true;
            subdomain = "ntfy";
        };

        borgbackup = {
            enable = true;
            passphraseSopsFile = ../../../secrets/hosts/vps.yaml;
        };

        # VPN
        wireguard = {
            enable = true;
            listenPort = 12333;
            serverIP = "10.13.13.1/24";
            subnet = "10.13.13.0/24";
            externalInterface = "enp1s0";
            peers = {
                homelab = {
                    publicKey = "8XESi3lyv2L/CUtGyfB/dWAgFz97NcgJXKhVq5Xp5XU=";
                    allowedIPs = [ "10.13.13.2/32" ];
                };
                pavel = {
                    publicKey = "RxKN8Gt9RCmSzsKsscHoXmgjzr2h3RNNI1Q/a+mAuUw=";
                    allowedIPs = [ "10.13.13.3/32" ];
                };
                pavel-pc = {
                    publicKey = "UJxCs19JHUg/oFNT0r/htvMRtm7YaHna4XSsIZJJDgs=";
                    allowedIPs = [ "10.13.13.4/32" ];
                };
                mom = {
                    publicKey = "ciuO1DyKt1wBNkIxEPWKyLlDLamXE1ozOx8DzTR5E20=";
                    allowedIPs = [ "10.13.13.5/32" ];
                };
                dad = {
                    publicKey = "AlZDosZZo7I/UAumgtE4PMcAkGn6XyHDKeQMIZ5/mw8=";
                    allowedIPs = [ "10.13.13.6/32" ];
                };
            };
        };
    };
}
