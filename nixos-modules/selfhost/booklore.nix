{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.booklore;
in
{
    options.homelab.booklore = {
        enable = mkEnableOption "BookLore digital library";

        subdomain = mkOption {
            type = types.str;
            description = "Subdomain for BookLore";
        };

        port = mkOption {
            type = types.int;
            default = 6060;
            description = "Port for BookLore web interface";
        };

        dataDir = mkOption {
            type = types.path;
            default = "/var/lib/booklore";
            description = "Directory for BookLore application data";
        };

        booksDir = mkOption {
            type = types.path;
            default = "/var/lib/booklore/books";
            description = "Directory for storing books";
        };

        bookdropDir = mkOption {
            type = types.path;
            default = "/var/lib/booklore/bookdrop";
            description = "Directory for BookDrop auto-import feature";
        };

        timezone = mkOption {
            type = types.str;
            default = if config.time.timeZone != null then config.time.timeZone else "UTC";
            description = "Timezone for BookLore (defaults to system timezone)";
        };
    };

    config = mkIf cfg.enable {
        sops.secrets."booklore_env" = {
            sopsFile = ../../secrets/shared/selfhost.yaml;
        };

        # Create necessary directories
        systemd.tmpfiles.rules = [
            "d ${cfg.dataDir} 0755 ${config.metadata.user} users -"
            "Z ${cfg.dataDir} 0755 ${config.metadata.user} users -"

            "d ${cfg.dataDir}/data 0755 ${config.metadata.user} users -"
            "Z ${cfg.dataDir}/data 0755 ${config.metadata.user} users -"

            "d ${cfg.dataDir}/mariadb 0755 ${config.metadata.user} users -"
            "Z ${cfg.dataDir}/mariadb 0755 ${config.metadata.user} users -"

            "d ${cfg.booksDir} 0777 ${config.metadata.user} users -"
            "Z ${cfg.booksDir} 0777 ${config.metadata.user} users -"

            "d ${cfg.bookdropDir} 0777 ${config.metadata.user} users -"
            "Z ${cfg.bookdropDir} 0777 ${config.metadata.user} users -"
        ];

        # MariaDB container for BookLore
        virtualisation.oci-containers.containers.booklore-mariadb = {
            image = "lscr.io/linuxserver/mariadb:11.4.5";
            environment = {
                PUID = "1000";
                PGID = "100";  # 'users' group
                TZ = cfg.timezone;
                MYSQL_DATABASE = "booklore";
                MYSQL_USER = "booklore";
            };
            environmentFiles = [
                config.sops.secrets."booklore_env".path
            ];
            volumes = [
                "${cfg.dataDir}/mariadb:/config"
            ];
            extraOptions = [
                "--network=booklore-net"
                "--health-cmd=mariadb-admin ping -h localhost"
                "--health-interval=5s"
                "--health-timeout=5s"
                "--health-retries=10"
            ];
        };

        # BookLore main container
        virtualisation.oci-containers.containers.booklore = {
            image = "booklore/booklore:latest";
            dependsOn = [ "booklore-mariadb" ];
            ports = [ "${toString cfg.port}:${toString cfg.port}" ];
            environment = {
                USER_ID = "1000";
                GROUP_ID = "100";  # 'users' group
                TZ = cfg.timezone;
                DATABASE_URL = "jdbc:mariadb://booklore-mariadb:3306/booklore";
                DATABASE_USERNAME = "booklore";
                BOOKLORE_PORT = toString cfg.port;
            };
            environmentFiles = [
                config.sops.secrets."booklore_env".path
            ];
            volumes = [
                "${cfg.dataDir}/data:/app/data"
                "${cfg.booksDir}:/books"
                "${cfg.bookdropDir}:/bookdrop"
            ];
            extraOptions = [
                "--network=booklore-net"
                "--pull=always"
            ];
        };

        # Create Docker network for BookLore services
        systemd.services.booklore-network = {
            description = "Create BookLore Docker network";
            wantedBy = [ "multi-user.target" ];
            before = [ "docker-booklore-mariadb.service" "docker-booklore.service" ];
            after = [ "docker.service" ];
            requires = [ "docker.service" ];
            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
            };
            script = ''
                ${pkgs.docker}/bin/docker network inspect booklore-net >/dev/null 2>&1 || \
                    ${pkgs.docker}/bin/docker network create booklore-net
            '';
            preStop = ''
                ${pkgs.docker}/bin/docker network rm booklore-net || true
            '';
        };

        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "booklore";
                subdomain = cfg.subdomain;
                backendUrl = "http://127.0.0.1:${toString cfg.port}";
            }
        ];

        homelab.glance.services = mkIf config.homelab.glance.enable [
            {
                title = "BookLore";
                subdomain = cfg.subdomain;
                icon = "mdi:book-open-page-variant";
                group = "Services";
            }
        ];
    };
}
