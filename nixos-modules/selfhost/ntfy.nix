{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.ntfy;
in
{
    options.homelab.ntfy = {
        enable = mkEnableOption "ntfy-sh push notification service";

        subdomain = mkOption {
            type = types.str;
            description = "Subdomain for ntfy";
        };

        port = mkOption {
            type = types.int;
            default = 8089;
            description = "Port for ntfy HTTP server";
        };

        enableWebPush = mkOption {
            type = types.bool;
            default = false;
            description = "Enable web push notifications (requires VAPID keys setup)";
        };
    };

    config = mkIf cfg.enable {

        services.ntfy-sh = {
            enable = true;
            environmentFile = config.sops.secrets."traefik/env".path;
            settings = {
                listen-http = "127.0.0.1:${toString cfg.port}";
                behind-proxy = true;
                base-url = "https://${cfg.subdomain}.\$DOMAIN";
                cache-file = "/var/lib/ntfy-sh/cache.db";
                auth-file = "/var/lib/ntfy-sh/auth.db";
                attachment-cache-dir = "/var/lib/ntfy-sh/attachments";
            };
        };

        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "ntfy";
                subdomain = cfg.subdomain;
                backendUrl = "http://127.0.0.1:${toString cfg.port}";
            }
        ];

        homelab.glance.services = mkIf config.homelab.glance.enable [
            {
                title = "Ntfy";
                subdomain = cfg.subdomain;
                icon = "mdi:bell-ring";
                group = "Other";
            }
        ];
    };
}

