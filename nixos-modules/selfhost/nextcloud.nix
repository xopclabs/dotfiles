{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.nextcloud;
in
{
    options.homelab.nextcloud = {
        enable = mkEnableOption "Nextcloud file storage";

        subdomain = mkOption {
            type = types.str;
            description = "Subdomain for Nextcloud";
        };

        package = mkOption {
            type = types.package;
            default = pkgs.nextcloud32;
            description = "Nextcloud package to use";
        };

        maxUploadSize = mkOption {
            type = types.str;
            default = "64G";
            description = "Maximum upload size";
        };
    };
    
    config = mkIf cfg.enable {
        sops.secrets."nextcloud/pavel-pass" = {
            sopsFile = ../../secrets/shared/selfhost.yaml;
            owner = "nextcloud";
            group = "nextcloud";
        };

        # Enable PostgreSQL with Nextcloud database
        homelab.postgres = {
            enable = true;
            databases = [ "nextcloud" ];
            ensureUsers = [
                {
                    name = "nextcloud";
                    ensureDBOwnership = true;
                }
            ];
        };

        services.nextcloud = {
            enable = true;
            package = cfg.package;
            hostName = "nextcloud-internal";
            datadir = config.metadata.selfhost.storage.general.nextcloudDir;
            
            config = {
                dbtype = "pgsql";
                dbhost = "/run/postgresql";
                dbname = "nextcloud";
                dbuser = "nextcloud";
                
                adminuser = "pavel";
                adminpassFile = config.sops.secrets."nextcloud/pavel-pass".path;
            };

            appstoreEnable = false;

            settings = {
                trusted_proxies = [ "127.0.0.1" "::1" ];
                overwriteprotocol = "https";
                memcache.local = "\\OC\\Memcache\\APCu";
            };

            # PHP settings for large uploads
            maxUploadSize = cfg.maxUploadSize;
            phpOptions = {
                "upload_max_filesize" = cfg.maxUploadSize;
                "post_max_size" = cfg.maxUploadSize;
                "memory_limit" = cfg.maxUploadSize;
                "opcache.interned_strings_buffer" = "16";
            };

            autoUpdateApps.enable = false;
            # Caching
            configureRedis = false;
        };

        # Ensure Nextcloud starts after PostgreSQL
        systemd.services.nextcloud-setup = {
            after = [ "postgresql.service" ];
            requires = [ "postgresql.service" ];
        };

        # Configure trusted domain from sops secret after setup
        systemd.services.nextcloud-trusted-domain = {
            description = "Configure Nextcloud trusted domain";
            after = [ "nextcloud-setup.service" ];
            requires = [ "nextcloud-setup.service" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
                Type = "oneshot";
                User = "nextcloud";
                EnvironmentFile = config.sops.secrets.traefik.path;
                ExecStart = pkgs.writeShellScript "nextcloud-trusted-domain" ''
                    FULL_DOMAIN="${cfg.subdomain}.$DOMAIN"
                    ${config.services.nextcloud.occ}/bin/nextcloud-occ config:system:set trusted_domains 1 --value="$FULL_DOMAIN"
                    ${config.services.nextcloud.occ}/bin/nextcloud-occ config:system:set overwritehost --value="$FULL_DOMAIN"
                '';
            };
        };

        # Ensure data directory has correct ownership
        systemd.tmpfiles.rules = [
            "d ${config.metadata.selfhost.storage.general.nextcloudDir} 0750 nextcloud nextcloud -"
        ];

        # # Configure nginx (required by Nextcloud module) for internal use
        services.nginx.virtualHosts."nextcloud-internal" = {
            listen = [{ addr = "127.0.0.1"; port = 8085; }];
        };

        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "nextcloud";
                subdomain = cfg.subdomain;
                backendUrl = "http://127.0.0.1:8085";
            }
        ];

        # Register with Glance dashboard
        homelab.glance.services = mkIf config.homelab.glance.enable [
            {
                title = "Nextcloud";
                subdomain = cfg.subdomain;
                icon = "si:nextcloud";
                group = "Services";
            }
        ];
    };
}

