{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.reitti;
    proxyPort = 10809;
    singBoxPort = config.desktop.singbox.listenPort;
    dockerGateway = "172.17.0.1";
    reittiSubnet = "172.18.0.0/16";

    watcherScript = pkgs.writeShellScript "reitti-gps-watcher" ''
        set -euo pipefail

        if [[ -z "''${REITTI_TOKEN:-}" ]]; then
            echo "Error: REITTI_TOKEN is not set in reitti_gps_env secret" >&2
            exit 1
        fi

        IMPORTED_DIR="''${REITTI_WATCH_DIR}/imported"
        mkdir -p "''${IMPORTED_DIR}"

        import_gpx() {
            local FILE="$1"
            local RESPONSE
            echo "Importing ''${FILE}"
            if ! RESPONSE=$(${pkgs.curl}/bin/curl -sS -X POST \
                -H "X-API-TOKEN: ''${REITTI_TOKEN}" \
                -F "file=@''${FILE}" \
                "''${REITTI_ENDPOINT}/api/v1/gpx/import"); then
                echo "Import request failed for ''${FILE}" >&2
                return 1
            fi
            echo "''${RESPONSE}" | ${pkgs.jq}/bin/jq -r '
                if .success == true then
                    "Points scheduled: \(.pointsScheduled)"
                else
                    "Import failed: \(.message // "unknown error")"
                end'
            echo "''${RESPONSE}" | ${pkgs.jq}/bin/jq -e '.success == true' >/dev/null
        }

        process_file() {
            local FILE="$1"
            [[ -f "''${FILE}" ]] || return 0
            case "''${FILE}" in
                *.zip)
                    echo "Unzipping ''${FILE}"
                    (cd "''${REITTI_WATCH_DIR}" && ${pkgs.unzip}/bin/unzip -o "''${FILE}" >/dev/null && mv -f "''${FILE}" "''${IMPORTED_DIR}/")
                    ;;
                *.gpx)
                    if import_gpx "''${FILE}"; then
                        mv -f "''${FILE}" "''${IMPORTED_DIR}/"
                    fi
                    ;;
                *)
                    echo "Ignoring ''${FILE} (not a GPX or ZIP file)"
                    ;;
            esac
        }

        echo "Waiting for Reitti at ''${REITTI_ENDPOINT}..."
        until ${pkgs.curl}/bin/curl -sS -o /dev/null --connect-timeout 2 --max-time 2 "''${REITTI_ENDPOINT}/"; do
            sleep 2
        done

        echo "Scanning ''${REITTI_WATCH_DIR} for pre-existing files..."
        shopt -s nullglob
        for FILE in "''${REITTI_WATCH_DIR}"/*.gpx "''${REITTI_WATCH_DIR}"/*.zip; do
            process_file "''${FILE}"
        done

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
                # Java's tile client uses an HTTP proxy, not SOCKS or HTTP_PROXY.
                JAVA_TOOL_OPTIONS = "-Dhttps.proxyHost=host.docker.internal -Dhttps.proxyPort=${toString proxyPort} -Dhttp.nonProxyHosts=localhost|127.*|reitti-postgis|reitti-redis";
                # The Docker profile defaults to a tile-cache container we don't run.
                REITTI_UI_TILES_CACHE_URL = "";
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
                "--add-host=host.docker.internal:host-gateway"
                "--pull=always"
            ];
        };

        # Only Reitti's Docker network can reach the proxy bridge.
        networking.firewall.extraCommands = ''
            ${pkgs.iptables}/bin/iptables -C nixos-fw -s ${reittiSubnet} -d ${dockerGateway} -p tcp --dport ${toString proxyPort} -j nixos-fw-accept 2>/dev/null || \
                ${pkgs.iptables}/bin/iptables -I nixos-fw -s ${reittiSubnet} -d ${dockerGateway} -p tcp --dport ${toString proxyPort} -j nixos-fw-accept
        '';
        networking.firewall.extraStopCommands = ''
            ${pkgs.iptables}/bin/iptables -D nixos-fw -s ${reittiSubnet} -d ${dockerGateway} -p tcp --dport ${toString proxyPort} -j nixos-fw-accept 2>/dev/null || true
        '';

        # Expose the loopback-only sing-box proxy to Reitti's container.
        systemd.services.reitti-tile-proxy = {
            description = "Bridge Reitti tile requests to the local sing-box proxy";
            wantedBy = [ "multi-user.target" ];
            after = [ "docker.service" "sing-box.service" ];
            requires = [ "docker.service" "sing-box.service" ];
            serviceConfig = {
                Type = "simple";
                Restart = "always";
                RestartSec = "5s";
            };
            script = ''
                GATEWAY=$(${pkgs.docker}/bin/docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}')
                test "$GATEWAY" = ${dockerGateway}
                exec ${pkgs.python3}/bin/python3 - "$GATEWAY" <<'PY'
                import asyncio
                import sys

                async def relay(reader, writer):
                    try:
                        while data := await reader.read(65536):
                            writer.write(data)
                            await writer.drain()
                        writer.write_eof()
                    except (ConnectionError, OSError):
                        pass

                async def forward(reader, writer):
                    try:
                        upstream_reader, upstream_writer = await asyncio.open_connection("127.0.0.1", ${toString singBoxPort})
                        await asyncio.gather(relay(reader, upstream_writer), relay(upstream_reader, writer))
                        upstream_writer.close()
                        await upstream_writer.wait_closed()
                    finally:
                        writer.close()
                        await writer.wait_closed()

                async def main():
                    server = await asyncio.start_server(forward, sys.argv[1], ${toString proxyPort})
                    async with server:
                        await server.serve_forever()

                asyncio.run(main())
                PY
            '';
        };

        systemd.services.docker-reitti = {
            after = [ "reitti-tile-proxy.service" ];
            requires = [ "reitti-tile-proxy.service" ];
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
            after = [ "docker.service" "docker.socket" ];
            wants = [ "docker.service" ];
            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
            };
            script = ''
                ${pkgs.docker}/bin/docker network inspect reitti-net >/dev/null 2>&1 || \
                    ${pkgs.docker}/bin/docker network create --subnet=${reittiSubnet} reitti-net
                test "$(${pkgs.docker}/bin/docker network inspect reitti-net --format '{{(index .IPAM.Config 0).Subnet}}')" = ${reittiSubnet}
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
