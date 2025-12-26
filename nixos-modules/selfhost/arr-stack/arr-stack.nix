{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.arr-stack;
    
    # Base NO_PROXY for private networks
    baseNoProxy = "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,localhost";
    
    # Environment file that will contain NO_PROXY with domain
    arrProxyEnvFile = "/run/arr-proxy.env";
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
            openFirewall = mkEnableOption "Open firewall for Prowlarr";
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
            openFirewall = mkEnableOption "Open firewall for Radarr";
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
            openFirewall = mkEnableOption "Open firewall for Sonarr";
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
            openFirewall = mkEnableOption "Open firewall for FlareSolverr";
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
            openFirewall = mkEnableOption "Open firewall for Jellyfin";
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
            openFirewall = mkEnableOption "Open firewall for Jellyseerr";
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

        bazarr = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable Bazarr subtitle manager for Sonarr and Radarr";
            };
            openFirewall = mkEnableOption "Open firewall for Bazarr";
            proxy = mkOption {
                type = types.bool;
                default = true;
                description = "Route Bazarr through xray proxy";
            };
            subdomain = mkOption {
                type = types.str;
                description = "Subdomain for Bazarr";
            };
        };
    };
    
    config = mkIf cfg.enable {
        # Reuse traefik's env file which contains DOMAIN
        sops.secrets."traefik/env" = {
            sopsFile = ../../../secrets/shared/selfhost.yaml;
        };

        # Generate proxy environment file with domain included in NO_PROXY
        systemd.services.arr-proxy-env = {
            description = "Generate arr-stack proxy environment file";
            wantedBy = [ "multi-user.target" ];
            before = [ 
                "prowlarr.service" "radarr.service" "sonarr.service" 
                "flaresolverr.service" "jellyfin.service" "jellyseerr.service" "bazarr.service"
            ];
            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
            };
            script = ''
                # Source traefik env to get DOMAIN variable
                set -a
                source ${config.sops.secrets."traefik/env".path}
                set +a
                
                ${pkgs.coreutils}/bin/cat > ${arrProxyEnvFile} <<EOF
                    HTTP_PROXY=http://127.0.0.1:10808
                    HTTPS_PROXY=http://127.0.0.1:10808
                    NO_PROXY=${baseNoProxy},.$DOMAIN
                EOF
                ${pkgs.coreutils}/bin/chmod 644 ${arrProxyEnvFile}
            '';
        };

        services.prowlarr = mkIf cfg.prowlarr.enable {
            enable = true;
            openFirewall = cfg.prowlarr.openFirewall;
        };
        systemd.services.prowlarr = mkIf cfg.prowlarr.proxy {
            after = [ "arr-proxy-env.service" ];
            requires = [ "arr-proxy-env.service" ];
            serviceConfig.EnvironmentFile = arrProxyEnvFile;
        };

        services.radarr = mkIf cfg.radarr.enable {
            enable = true;
            openFirewall = cfg.radarr.openFirewall;
            group = "users";
        };
        systemd.services.radarr = mkIf cfg.radarr.proxy {
            after = [ "arr-proxy-env.service" ];
            requires = [ "arr-proxy-env.service" ];
            serviceConfig.EnvironmentFile = arrProxyEnvFile;
        };

        services.sonarr = mkIf cfg.sonarr.enable {
            enable = true;
            openFirewall = cfg.sonarr.openFirewall;
            group = "users";
        };
        systemd.services.sonarr = mkIf cfg.sonarr.proxy {
            after = [ "arr-proxy-env.service" ];
            requires = [ "arr-proxy-env.service" ];
            serviceConfig.EnvironmentFile = arrProxyEnvFile;
        };

        services.flaresolverr = mkIf cfg.flaresolverr.enable {
            enable = true;
            openFirewall = cfg.flaresolverr.openFirewall;
        };
        systemd.services.flaresolverr = mkIf cfg.flaresolverr.proxy {
            after = [ "arr-proxy-env.service" ];
            requires = [ "arr-proxy-env.service" ];
            serviceConfig.EnvironmentFile = arrProxyEnvFile;
        };

        services.jellyfin = mkIf cfg.jellyfin.enable {
            enable = true;
            openFirewall = cfg.jellyfin.openFirewall;
            # If we setup a user to homelab, jellyfin doesn't start, perhaps due to /var/lib ownership
            group = "users";
        };
        systemd.services.jellyfin = mkIf cfg.jellyfin.proxy {
            after = [ "arr-proxy-env.service" ];
            requires = [ "arr-proxy-env.service" ];
            serviceConfig.EnvironmentFile = arrProxyEnvFile;
        };

        services.jellyseerr = mkIf cfg.jellyseerr.enable {
            enable = true;
            port = 15055;
            openFirewall = cfg.jellyseerr.openFirewall;
        };
        systemd.services.jellyseerr = mkIf cfg.jellyseerr.proxy {
            after = [ "arr-proxy-env.service" ];
            requires = [ "arr-proxy-env.service" ];
            serviceConfig.EnvironmentFile = arrProxyEnvFile;
        };

        services.bazarr = mkIf cfg.bazarr.enable {
            enable = true;
            openFirewall = cfg.bazarr.openFirewall;
        };
        systemd.services.bazarr = mkIf cfg.bazarr.proxy {
            after = [ "arr-proxy-env.service" ];
            requires = [ "arr-proxy-env.service" ];
            serviceConfig.EnvironmentFile = arrProxyEnvFile;
        };

        # Create necessary directories for media (d) and ensure permissions (Z)
        systemd.tmpfiles.rules = [
            "d ${config.metadata.selfhost.storage.media.moviesDir} 0777 ${config.metadata.user} users -"
            "Z ${config.metadata.selfhost.storage.media.moviesDir} 0777 ${config.metadata.user} users -"
            "d ${config.metadata.selfhost.storage.media.tvDir} 0777 ${config.metadata.user} users -"
            "Z ${config.metadata.selfhost.storage.media.tvDir} 0777 ${config.metadata.user} users -"
            "d ${config.metadata.selfhost.storage.media.musicDir} 0777 ${config.metadata.user} users -"
            "Z ${config.metadata.selfhost.storage.media.musicDir} 0777 ${config.metadata.user} users -"
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
            ]) ++
            (optionals cfg.bazarr.enable [
                {
                    name = "bazarr";
                    subdomain = cfg.bazarr.subdomain;
                    backendUrl = "http://127.0.0.1:${toString config.services.bazarr.listenPort}";
                }
            ])
        );

        # Register with Glance dashboard
        homelab.glance.services = mkIf config.homelab.glance.enable (
            (optionals cfg.jellyfin.enable [
                {
                    title = "Jellyfin";
                    subdomain = cfg.jellyfin.subdomain;
                    icon = "si:jellyfin";
                    group = "Services";
                    priority = 1;
                }
            ]) ++
            (optionals cfg.jellyseerr.enable [
                {
                    title = "Jellyseerr";
                    subdomain = cfg.jellyseerr.subdomain;
                    icon = "mdi:jellyfish";
                    group = "Services";
                    priority = 2;
                }
            ]) ++
            (optionals cfg.radarr.enable [
                {
                    title = "Radarr";
                    subdomain = cfg.radarr.subdomain;
                    icon = "si:radarr";
                    group = "*arr";
                    priority = 2;
                }
            ]) ++
            (optionals cfg.sonarr.enable [
                {
                    title = "Sonarr";
                    subdomain = cfg.sonarr.subdomain;
                    icon = "si:sonarr";
                    group = "*arr";
                    priority = 3;
                }
            ]) ++
            (optionals cfg.bazarr.enable [
                {
                    title = "Bazarr";
                    subdomain = cfg.bazarr.subdomain;
                    icon = "mdi:subtitles";
                    group = "*arr";
                }
            ]) ++
            (optionals cfg.prowlarr.enable [
                {
                    title = "Prowlarr";
                    subdomain = cfg.prowlarr.subdomain;
                    icon = "mdi:cat";
                    group = "*arr";
                }
            ])
        );
    };
}

