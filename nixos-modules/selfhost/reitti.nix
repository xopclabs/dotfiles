{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.reitti;

    watcherScript = pkgs.writeShellScript "reitti-gps-watcher" ''
        set -euo pipefail

        if [[ -z "''${REITTI_TOKEN:-}" ]]; then
            echo "Error: REITTI_TOKEN is not set in reitti_gps_env secret" >&2
            exit 1
        fi

        import_gpx() {
            local FILE="$1"
            echo "Importing ''${FILE}"
            ${pkgs.curl}/bin/curl -s -X POST \
                -H "X-API-TOKEN: ''${REITTI_TOKEN}" \
                -F "file=@''${FILE}" \
                "''${REITTI_ENDPOINT}/api/v1/gpx/import" | \
                ${pkgs.jq}/bin/jq -r '
                    if .success == true then
                        "Points scheduled: \(.pointsScheduled)"
                    else
                        "Import failed: \(.message // "unknown error")"
                    end'
        }

        process_file() {
            local FILE="$1"
            [[ -f "''${FILE}" ]] || return 0
            case "''${FILE}" in
                *.zip)
                    echo "Unzipping ''${FILE}"
                    (cd "''${REITTI_WATCH_DIR}" && ${pkgs.unzip}/bin/unzip -o "''${FILE}" >/dev/null && rm -f "''${FILE}")
                    ;;
                *.gpx)
                    import_gpx "''${FILE}"
                    ;;
                *)
                    echo "Ignoring ''${FILE} (not a GPX or ZIP file)"
                    ;;
            esac
        }

        # Process any files already present in the directory at startup
        echo "Scanning ''${REITTI_WATCH_DIR} for pre-existing files..."
        for FILE in "''${REITTI_WATCH_DIR}"/*.gpx "''${REITTI_WATCH_DIR}"/*.zip; do
            [[ -f "''${FILE}" ]] && process_file "''${FILE}"
        done

        # Watch for new files: close_write (normal write) and moved_to (SFTP atomic rename)
        echo "Watching ''${REITTI_WATCH_DIR} for GPX/ZIP uploads..."
        ${pkgs.inotify-tools}/bin/inotifywait -m -e close_write -e moved_to "''${REITTI_WATCH_DIR}" --format '%w%f' |
        while read -r FILE; do
            process_file "''${FILE}"
        done
    '';
in
{
    options.homelab.reitti = {
        enable = mkEnableOption "Reitti personal location tracking and analysis";

        subdomain = mkOption {
            type = types.str;
            description = "Subdomain for Reitti";
        };

        port = mkOption {
            type = types.int;
            default = 8095;
            description = "Port for Reitti web interface";
        };

        dataDir = mkOption {
            type = types.path;
            default = "/var/lib/reitti";
            description = "Directory for Reitti persistent data (PostGIS data and Reitti uploads)";
        };

        timezone = mkOption {
            type = types.str;
            default = if config.time.timeZone != null then config.time.timeZone else "UTC";
            description = "Timezone for Reitti (defaults to system timezone)";
        };

        advertiseUri = mkOption {
            type = types.str;
            default = "";
            description = "Routable public URL of the instance. Used for federation of multiple instances.";
        };

        processingWaitTime = mkOption {
            type = types.int;
            default = 15;
            description = "Seconds to wait after the last data input before processing. Must be lower than your mobile app's reporting interval.";
        };

        gps = {
            enable = mkEnableOption "SFTP drop zone with auto-import of GPX files into Reitti";

            zfsDataset = mkOption {
                type = types.str;
                default = "raid_pool/gps";
                description = "ZFS dataset to create for GPS data. Must be created manually with: zfs create -o mountpoint=/mnt/raid_pool/gps <dataset>";
            };

            chrootDir = mkOption {
                type = types.path;
                default = "/mnt/raid_pool/gps";
                description = "SFTP chroot directory (must be owned by root:root). GPSLogger connects here as its root.";
            };

            uploadDir = mkOption {
                type = types.path;
                default = "/mnt/raid_pool/gps/uploads";
                description = "Subdirectory inside the chroot where GPSLogger deposits files. Watched by the auto-import service.";
            };

            authorizedKeys = mkOption {
                type = types.listOf types.str;
                default = [];
                description = "SSH public keys for the gpslogger SFTP user (generated on your Android phone).";
                example = [ "ssh-ed25519 AAAA... gpslogger@android" ];
            };
        };
    };

    config = mkIf cfg.enable {
        sops.secrets."reitti_env" = {
            sopsFile = ../../secrets/shared/selfhost.yaml;
        };

        systemd.tmpfiles.rules = [
            "d ${cfg.dataDir} 0755 ${config.metadata.user} users -"
            "d ${cfg.dataDir}/postgis 0755 ${config.metadata.user} users -"
            "d ${cfg.dataDir}/data 0755 ${config.metadata.user} users -"
        ] ++ optionals cfg.gps.enable [
            # Chroot root must be owned root:root and not group/world writable (OpenSSH requirement)
            "d ${toString cfg.gps.chrootDir} 0755 root root -"
            "z ${toString cfg.gps.chrootDir} 0755 root root -"
            # Upload subdir is owned by the SFTP user
            "d ${toString cfg.gps.uploadDir} 0775 gpslogger users -"
        ];

        # PostGIS container (requires PostgreSQL + PostGIS spatial extensions)
        virtualisation.oci-containers.containers.reitti-postgis = {
            image = "postgis/postgis:17-3.5-alpine";
            environment = {
                POSTGRES_DB = "reittidb";
                POSTGRES_USER = "reitti";
            };
            environmentFiles = [
                config.sops.secrets."reitti_env".path
            ];
            volumes = [
                "${cfg.dataDir}/postgis:/var/lib/postgresql/data"
            ];
            extraOptions = [
                "--network=reitti-net"
                "--health-cmd=pg_isready -U reitti -d reittidb"
                "--health-interval=5s"
                "--health-timeout=5s"
                "--health-retries=10"
            ];
        };

        # Redis container for caching and task scheduling
        virtualisation.oci-containers.containers.reitti-redis = {
            image = "redis:alpine";
            extraOptions = [
                "--network=reitti-net"
                "--health-cmd=redis-cli ping"
                "--health-interval=5s"
                "--health-timeout=5s"
                "--health-retries=10"
            ];
        };

        # Reitti application container
        virtualisation.oci-containers.containers.reitti = {
            image = "dedicatedcode/reitti:latest";
            dependsOn = [ "reitti-postgis" "reitti-redis" ];
            ports = [ "${toString cfg.port}:8080" ];
            environment = {
                POSTGIS_HOST = "reitti-postgis";
                POSTGIS_PORT = "5432";
                POSTGIS_DB = "reittidb";
                POSTGIS_USER = "reitti";
                REDIS_HOST = "reitti-redis";
                REDIS_PORT = "6379";
                TZ = cfg.timezone;
                PROCESSING_WAIT_TIME = toString cfg.processingWaitTime;
            } // optionalAttrs (cfg.advertiseUri != "") {
                ADVERTISE_URI = cfg.advertiseUri;
            };
            environmentFiles = [
                config.sops.secrets."reitti_env".path
            ];
            volumes = [
                "${cfg.dataDir}/data:/data"
            ];
            extraOptions = [
                "--network=reitti-net"
                "--pull=always"
            ];
        };

        # Docker network for Reitti services
        systemd.services.reitti-network = {
            description = "Create Reitti Docker network";
            wantedBy = [ "multi-user.target" ];
            before = [
                "docker-reitti-postgis.service"
                "docker-reitti-redis.service"
                "docker-reitti.service"
            ];
            after = [ "docker.service" ];
            requires = [ "docker.service" ];
            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
            };
            script = ''
                ${pkgs.docker}/bin/docker network inspect reitti-net >/dev/null 2>&1 || \
                    ${pkgs.docker}/bin/docker network create reitti-net
            '';
            preStop = ''
                ${pkgs.docker}/bin/docker network rm reitti-net || true
            '';
        };

        # GPS SFTP drop zone and auto-import watcher
        users.users.gpslogger = mkIf cfg.gps.enable {
            isSystemUser = true;
            group = "users";
            home = toString cfg.gps.chrootDir;
            createHome = false;
            openssh.authorizedKeys.keys = cfg.gps.authorizedKeys;
        };

        services.openssh.extraConfig = mkIf cfg.gps.enable ''
            Match User gpslogger
                ChrootDirectory ${toString cfg.gps.chrootDir}
                ForceCommand internal-sftp
                AllowTcpForwarding no
                X11Forwarding no
                PasswordAuthentication no
        '';

        sops.secrets."reitti_gps_env" = mkIf cfg.gps.enable {
            sopsFile = ../../secrets/shared/selfhost.yaml;
        };

        # Watches the SFTP upload directory and calls Reitti's GPX import API
        systemd.services.reitti-gps-watcher = mkIf cfg.gps.enable {
            description = "Reitti GPX file watcher for SFTP uploads";
            after = [ "docker-reitti.service" "network.target" ];
            requires = [ "docker-reitti.service" ];
            wantedBy = [ "multi-user.target" ];
            environment = {
                REITTI_ENDPOINT = "http://127.0.0.1:${toString cfg.port}";
                REITTI_WATCH_DIR = toString cfg.gps.uploadDir;
            };
            serviceConfig = {
                Type = "simple";
                EnvironmentFile = config.sops.secrets."reitti_gps_env".path;
                ExecStart = watcherScript;
                Restart = "always";
                RestartSec = "5s";
            };
        };

        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "reitti";
                subdomain = cfg.subdomain;
                backendUrl = "http://127.0.0.1:${toString cfg.port}";
            }
        ];

        homelab.glance.services = mkIf config.homelab.glance.enable [
            {
                title = "Reitti";
                subdomain = cfg.subdomain;
                icon = "mdi:map-marker-path";
                group = "Services";
            }
        ];
    };
}
