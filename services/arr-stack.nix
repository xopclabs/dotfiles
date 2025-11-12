{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.arr-stack;
in
{
    options.homelab.arr-stack = {
        enable = mkEnableOption "*arr stack";

        prowlarr = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable Prowlarr indexer manager";
            };
            subdomain = mkOption {
                type = types.str;
                description = "Subdomain for Prowlarr";
            };
        };

        radarr = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable Radarr movie manager";
            };
            subdomain = mkOption {
                type = types.str;
                description = "Subdomain for Radarr";
            };
        };

        sonarr = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable Sonarr TV show manager";
            };
            subdomain = mkOption {
                type = types.str;
                description = "Subdomain for Sonarr";
            };
        };
    };
    
    config = mkIf cfg.enable {
        services.prowlarr = mkIf cfg.prowlarr.enable {
            enable = true;
            openFirewall = false;
        };

        services.radarr = mkIf cfg.radarr.enable {
            enable = true;
            openFirewall = false;
        };

        services.sonarr = mkIf cfg.sonarr.enable {
            enable = true;
            openFirewall = false;
        };

        # Create necessary directories for media and downloads
        systemd.tmpfiles.rules = [
            # Download directories
            "d ${config.metadata.selfhost.storage.downloads.moviesDir} 0775 radarr radarr -"
            "d ${config.metadata.selfhost.storage.downloads.tvDir} 0775 sonarr sonarr -"
            
            # Media directories
            "d ${config.metadata.selfhost.storage.media.moviesDir} 0775 radarr radarr -"
            "d ${config.metadata.selfhost.storage.media.tvDir} 0775 sonarr sonarr -"
        ];

        # Register with Traefik
        homelab.traefik.routes = mkIf config.homelab.traefik.enable (
            (optionals cfg.prowlarr.enable [
                {
                    name = "prowlarr";
                    subdomain = cfg.prowlarr.subdomain;
                    backendUrl = "http://127.0.0.1:9696";
                }
            ]) ++
            (optionals cfg.radarr.enable [
                {
                    name = "radarr";
                    subdomain = cfg.radarr.subdomain;
                    backendUrl = "http://127.0.0.1:7878";
                }
            ]) ++
            (optionals cfg.sonarr.enable [
                {
                    name = "sonarr";
                    subdomain = cfg.sonarr.subdomain;
                    backendUrl = "http://127.0.0.1:8989";
                }
            ])
        );
    };
}

