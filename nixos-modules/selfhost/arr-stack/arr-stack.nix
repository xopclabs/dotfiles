{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.arr-stack;
in
{
    imports = [
        ./cleanuparr.nix
        ./huntarr.nix
    ];

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
            proxy = mkOption {
                type = types.bool;
                default = true;
                description = "Route Radarr through xray proxy";
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
            proxy = mkOption {
                type = types.bool;
                default = true;
                description = "Route Sonarr through xray proxy";
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

        jellyfin = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable Jellyfin media server";
            };
            proxy = mkOption {
                type = types.bool;
                default = true;
                description = "Route Jellyfin through xray proxy";
            };
            subdomain = mkOption {
                type = types.str;
                description = "Subdomain for Jellyfin";
            };
        };

        jellyseerr = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable Jellyseerr media request manager";
            };
            proxy = mkOption {
                type = types.bool;
                default = true;
                description = "Route Jellyseerr through xray proxy";
            };
            subdomain = mkOption {
                type = types.str;
                description = "Subdomain for Jellyseerr";
            };
        };
    };
    
    config = mkIf cfg.enable {
        services.prowlarr = mkIf cfg.prowlarr.enable {
            enable = true;
            openFirewall = false;
        };
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
        systemd.services.radarr = mkIf cfg.radarr.proxy {
            environment = {
                HTTP_PROXY = "socks5://127.0.0.1:10808";
                HTTPS_PROXY = "socks5://127.0.0.1:10808";
                NO_PROXY = "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,localhost";
            };
        };

        services.sonarr = mkIf cfg.sonarr.enable {
            enable = true;
            openFirewall = false;
        };
        systemd.services.sonarr = mkIf cfg.sonarr.proxy {
            environment = {
                HTTP_PROXY = "socks5://127.0.0.1:10808";
                HTTPS_PROXY = "socks5://127.0.0.1:10808";
                NO_PROXY = "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,localhost";
            };
        };

        services.flaresolverr = mkIf cfg.flaresolverr.enable {
            enable = true;
            openFirewall = false;
        };
        systemd.services.flaresolverr = mkIf cfg.flaresolverr.proxy {
            environment = {
                HTTP_PROXY = "socks5://127.0.0.1:10808";
                HTTPS_PROXY = "socks5://127.0.0.1:10808";
                NO_PROXY = "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,localhost";
            };
        };

        services.jellyfin = mkIf cfg.jellyfin.enable {
            enable = true;
            openFirewall = false;
        };
        systemd.services.jellyfin = mkIf cfg.jellyfin.proxy {
            environment = {
                HTTP_PROXY = "socks5://127.0.0.1:10808";
                HTTPS_PROXY = "socks5://127.0.0.1:10808";
                NO_PROXY = "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,localhost";
            };
        };

        services.jellyseerr = mkIf cfg.jellyseerr.enable {
            enable = true;
            port = 15055;
            openFirewall = false;
        };
        systemd.services.jellyseerr = mkIf cfg.jellyseerr.proxy {
            environment = {
                HTTP_PROXY = "socks5://127.0.0.1:10808";
                HTTPS_PROXY = "socks5://127.0.0.1:10808";
                NO_PROXY = "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,localhost";
            };
        };

        # Create necessary directories for media
        systemd.tmpfiles.rules = [
            "d ${config.metadata.selfhost.storage.media.moviesDir} 0777 ${config.metadata.user} ${config.metadata.user} -"
            "d ${config.metadata.selfhost.storage.media.tvDir} 0777 ${config.metadata.user} ${config.metadata.user} -"
            "d ${config.metadata.selfhost.storage.media.musicDir} 0777 ${config.metadata.user} ${config.metadata.user} -"
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
                    backendUrl = "http://127.0.0.1:${toString config.services.flaresolverr.port}";
                }
            ]) ++
            (optionals cfg.jellyfin.enable [
                {
                    name = "jellyfin";
                    subdomain = cfg.jellyfin.subdomain;
                    backendUrl = "http://127.0.0.1:8096";
                }
            ]) ++
            (optionals cfg.jellyseerr.enable [
                {
                    name = "jellyseerr";
                    subdomain = cfg.jellyseerr.subdomain;
                    backendUrl = "http://127.0.0.1:${toString config.services.jellyseerr.port}";
                }
            ])
        );
    };
}

