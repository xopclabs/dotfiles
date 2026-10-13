{ ... }:

{
    imports = [ ../../../nixos-modules/selfhost/default.nix ];

    homelab = {
        home-assistant.enable = true;

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
