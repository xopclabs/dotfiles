{ config, lib, ... }:

with lib;
let
    cfg = config.homelab.wallpaper-generator;
    isPublic = builtins.match ".*\\.local$" cfg.subdomain == null;
    rateLimitEnabled = if cfg.rateLimit != null then cfg.rateLimit else isPublic;
in
{
    options.homelab.wallpaper-generator = {
        enable = mkEnableOption "procedural wallpaper HTTP service";

        subdomain = mkOption {
            type = types.str;
            description = ''
                Subdomain for the wallpaper generator.
                Use `wallpaper` for public wallpaper.$DOMAIN, or a `*.vps.local` name for VPN-only access.
            '';
        };

        port = mkOption {
            type = types.port;
            default = 8000;
            description = "Local port for the HTTP service (bound to localhost only)";
        };

        rateLimit = mkOption {
            type = types.nullOr types.bool;
            default = null;
            description = ''
                Apply Traefik rate limiting to the wallpaper-generator route.
                Null auto-enables for public subdomains (not ending in .local).
            '';
        };
    };

    config = mkIf cfg.enable {
        services.wallpaper-generator = {
            enable = true;
            listenAddress = "127.0.0.1";
            port = cfg.port;
        };

        services.traefik.dynamicConfigOptions.http.middlewares = mkIf rateLimitEnabled {
            wallpaper-generator-ratelimit.rateLimit = {
                # Generation is CPU-heavy and cache-bypass is a unique seed per request.
                average = 10;
                burst = 20;
                period = "1m";
            };
        };

        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "wallpaper-generator";
                subdomain = cfg.subdomain;
                backendUrl = "http://127.0.0.1:${toString cfg.port}";
                middlewares =
                    if rateLimitEnabled
                    then [ "default-headers" "https-redirect" "wallpaper-generator-ratelimit" ]
                    else null;
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
