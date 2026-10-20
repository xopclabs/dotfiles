{ config, ... }:

{
    imports = [ ../../../nixos-modules/selfhost/default.nix ];

    homelab = {
        home-assistant = {
            enable = true;
            vpnAccess.wg-telemetry = [ "10.250.250.1/32" ];
            provisioning.users.esp32-remote = {
                name = "ESP32 Remote";
                passwordSecret = "smart-home/ha-esp32-remote-password";
            };
        };
        cat-printer = {
            enable = true;
            deviceAddress = "DD:12:29:32:E0:F1";
            lanAccess.enable = true;
            share = {
                enable = true;
                expiresAt = 1797811200; # 2026-12-21 00:00:00 UTC
                relayAddress = "10.13.13.7";
                ingressAddress = "10.13.13.1";
                relayInterface = "wg-vps";
            };
        };
        wireguard.clients = {
            telemetry = {
                address = "10.250.250.11/32";
                routeAllTraffic = true;
                peer = {
                    publicKey = "yWcz2fBg4UaSANLSmYu57jhxB/f+nMIJ4Z+77GKEBDA=";
                    allowedIPs = [ "10.250.250.0/24" "192.168.254.10/32" ];
                };
            };
            vps = {
                address = "10.13.13.7/32";
                routeAllTraffic = true;
                peer = {
                    publicKey = "FPVXWSxA7pu4YznVvoqTPdJilNYghEA6Z8bBj69GqQg=";
                    allowedIPs = [ "10.13.13.1/32" ];
                };
            };
        };
        telemetry.edge = {
            enable = true;
            deviceAddress = config.metadata.network.ipv4;
        };

        traefik = {
            enable = true;
            dashboardSubdomain = "traefik.laptop.remote";
            certificateDomains = [ {
                main = "*.laptop.remote.$DOMAIN";
                sans = [ "laptop.remote.$DOMAIN" ];
            } ];
        };
    };
}
