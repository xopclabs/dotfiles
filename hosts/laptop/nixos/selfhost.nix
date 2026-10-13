{ ... }:

{
    imports = [ ../../../nixos-modules/selfhost/default.nix ];

    homelab = {
        home-assistant.enable = true;
        telemetry.edge = {
            enable = true;
            deviceAddress = "192.168.1.155";
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
