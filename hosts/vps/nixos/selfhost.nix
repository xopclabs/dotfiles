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
            pihole.subdomain = "pihole.vps.local";
        };

        # VPN
        wireguard = {
            enable = true;
            listenPort = 12333;
            serverIP = "10.250.250.1/24";
            subnet = "10.250.250.0/24";
            externalInterface = "ens18";
            peers = {
                pavel = {
                    publicKey = "1LXVJGpJcmtb/QawSGDeNxO6DcFZG1PoipDmhtTvJxI=";
                    allowedIPs = [ "10.250.250.102/32" ];
                };
            };
        };
    };
}
