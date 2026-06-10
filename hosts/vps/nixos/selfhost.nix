{ config, lib, inputs, ... }:

{
    imports = [ 
        ../../../nixos-modules/selfhost/default.nix
    ];
    
    config.homelab = {
        # Essentials
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

        # VPN
        wireguard = {
            enable = true;
            listenPort = 12333;
            serverIP = "10.13.13.1/24";
            subnet = "10.13.13.0/24";
            externalInterface = "enp1s0";
            peers = {
                homelab = {
                    publicKey = "O97secDiMhizN4f4m5QjO2QgXMJr172Fia6G7v9/uiQ=";
                    allowedIPs = [ "10.13.13.2/32" ];
                };
                pavel = {
                    publicKey = "RxKN8Gt9RCmSzsKsscHoXmgjzr2h3RNNI1Q/a+mAuUw=";
                    allowedIPs = [ "10.13.13.3/32" ];
                };
            };
        };
    };
}
