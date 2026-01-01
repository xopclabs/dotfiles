{ config, lib, pkgs, inputs, ... }:

with lib;
let
    cfg = config.homelab.shadowing;
in
{
    options.homelab.shadowing = {
        enable = mkEnableOption "Shadowing Spanish pronunciation practice app";

        subdomain = mkOption {
            type = types.str;
            description = "Subdomain for Shadowing";
        };

        port = mkOption {
            type = types.int;
            default = 8847;
            description = "Port for the service";
        };

        dataDir = mkOption {
            type = types.path;
            default = "/var/lib/shadowing";
            description = "Directory for data storage (database, recordings, clips)";
        };

        mediaDir = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Base directory for media files (optional, for browsing external media)";
        };
    };

    config = mkIf cfg.enable {
        # Enable the shadowing service from the flake
        services.shadowing = {
            enable = true;
            port = cfg.port;
            dataDir = cfg.dataDir;
        } // lib.optionalAttrs (cfg.mediaDir != null) {
            mediaDir = cfg.mediaDir;
        };

        # Traefik route
        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "shadowing";
                subdomain = cfg.subdomain;
                backendUrl = "http://127.0.0.1:${toString cfg.port}";
            }
        ];

        # Glance dashboard entry
        homelab.glance.services = mkIf config.homelab.glance.enable [
            {
                title = "Shadowing";
                subdomain = cfg.subdomain;
                icon = "mdi:microphone";
                group = "Other";
            }
        ];
    };
}
