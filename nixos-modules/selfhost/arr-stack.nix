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
            proxy = mkOption {
                type = types.bool;
                default = true;
                description = "Route Prowlarr through xray proxy";
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

        flaresolverr = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable FlareSolverr proxy for Cloudflare bypass";
            };
            proxy = mkOption {
                type = types.bool;
                default = true;
                description = "Route FlareSolverr through xray proxy";
            };
            subdomain = mkOption {
                type = types.str;
                description = "Subdomain for FlareSolverr";
            };
        };
    };
    
    config = mkIf cfg.enable {
        services.prowlarr = mkIf cfg.prowlarr.enable {
            enable = true;
            openFirewall = false;
        };
        # Route Prowlarr through xray proxy
        systemd.services.prowlarr = mkIf cfg.prowlarr.proxy {
            environment = {
                HTTP_PROXY = "socks5://127.0.0.1:10808";
                HTTPS_PROXY = "socks5://127.0.0.1:10808";
                NO_PROXY = "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,localhost";
            };
        };

        services.radarr = mkIf cfg.radarr.enable {
            enable = true;
            openFirewall = false;
        };

        services.sonarr = mkIf cfg.sonarr.enable {
            enable = true;
            openFirewall = false;
        };

        services.flaresolverr = mkIf cfg.flaresolverr.enable {
            enable = true;
            openFirewall = false;
        };
        # Route FlareSolverr through xray proxy
        systemd.services.flaresolverr = mkIf cfg.flaresolverr.proxy {
            environment = {
                HTTP_PROXY = "socks5://127.0.0.1:10808";
                HTTPS_PROXY = "socks5://127.0.0.1:10808";
                NO_PROXY = "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,localhost";
            };
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
            ]) ++
            (optionals cfg.flaresolverr.enable [
                {
                    name = "flaresolverr";
                    subdomain = cfg.flaresolverr.subdomain;
                    backendUrl = "http://127.0.0.1:8191";
                }
            ])
        );
    };
}

