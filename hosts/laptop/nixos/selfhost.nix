{ config, ... }:

{
    imports = [ ../../../nixos-modules/selfhost/default.nix ];

    homelab = {
        home-assistant = {
            enable = true;
            vpnAccess.telemetry = [ "10.250.250.1/32" ];
            provisioning.users.esp32-remote = {
                name = "ESP32 Remote";
                passwordSecret = "smart-home/ha-esp32-remote-password";
            };
        };
        cat-printer = {
            enable = true;
            deviceAddress = "DD:12:29:32:E0:F1";
            lanAccess.enable = true;
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
