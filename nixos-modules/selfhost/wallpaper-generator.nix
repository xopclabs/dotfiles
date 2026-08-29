{ config, lib, ... }:

with lib;
let
    cfg = config.homelab.wallpaper-generator;
in
{
    options.homelab.wallpaper-generator = {
        enable = mkEnableOption "procedural wallpaper HTTP service";

        subdomain = mkOption {
            type = types.str;
            description = ''
                Subdomain for the wallpaper generator.
                Use a `*.vps.local` name so Traefik keeps it on the VPN whitelist.
            '';
        };

        port = mkOption {
            type = types.port;
            default = 8000;
            description = "Local port for the HTTP service (bound to localhost only)";
        };
    };

    config = mkIf cfg.enable {
        services.wallpaper-generator = {
            enable = true;
            listenAddress = "127.0.0.1";
            port = cfg.port;
        };

        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "wallpaper-generator";
                subdomain = cfg.subdomain;
                backendUrl = "http://127.0.0.1:${toString cfg.port}";
            }
        ];

        homelab.glance.services = mkIf config.homelab.glance.enable [
            {
                title = "Wallpapers";
                subdomain = cfg.subdomain;
                icon = "mdi:wallpaper";
                group = "Other";
            }
        ];
    };
}
