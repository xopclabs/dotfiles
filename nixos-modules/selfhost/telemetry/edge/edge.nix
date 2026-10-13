{ config, lib, pkgs, ... }:

let
    cfg = config.homelab.telemetry.edge;
    python = pkgs.python3.withPackages (ps: [ ps.paho-mqtt ]);
in
{
    options.homelab.telemetry.edge = {
        enable = lib.mkEnableOption "durable apartment MQTT collection and forwarding";
        deviceAddress = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Optional LAN listener for telemetry device publishers.";
        };
        remoteHost = lib.mkOption {
            type = lib.types.str;
            default = "10.250.250.1";
            description = "MQTT host acknowledging committed telemetry records.";
        };
        clientPrefix = lib.mkOption {
            type = lib.types.str;
            default = "apartment-${config.networking.hostName}";
            description = "Stable, unique prefix for the collector and upstream MQTT sessions.";
        };
    };

    config = lib.mkIf cfg.enable {
        services.mosquitto.enable = true;
        sops.secrets = (lib.genAttrs [
            "mqtt/edge/mqtt-admin/password"
            "mqtt/edge/air-sensor/password"
            "mqtt/edge/shelly-plugs/password"
            "mqtt/edge/telemetry-forwarder/password"
        ] (name: {
            sopsFile = ../../../../secrets/shared/selfhost.yaml;
            restartUnits = [ "mosquitto.service" ]
                ++ lib.optional (name == "mqtt/edge/telemetry-forwarder/password") "telemetry-forwarder.service";
        })) // {
            "mqtt/homelab/apartment-bridge/password" = {
                sopsFile = ../../../../secrets/shared/selfhost.yaml;
                restartUnits = [ "telemetry-forwarder.service" ];
            };
        };
        homelab.mosquitto.listeners = {
            local = {
                address = "127.0.0.1";
                users.telemetry-forwarder = {
                    passwordFile = config.sops.secrets."mqtt/edge/telemetry-forwarder/password".path;
                    acl = [ "read apartment/#" "read homeassistant/#" "read home/apartment/#" ];
                };
            };
        } // lib.optionalAttrs (cfg.deviceAddress != null) {
            devices = {
                address = cfg.deviceAddress;
                users = {
                    mqtt-admin = {
                        passwordFile = config.sops.secrets."mqtt/edge/mqtt-admin/password".path;
                        acl = [ "readwrite #" ];
                    };
                    shelly-plugs = {
                        passwordFile = config.sops.secrets."mqtt/edge/shelly-plugs/password".path;
                        acl = [ "readwrite apartment/#" ];
                    };
                    air-sensor = {
                        passwordFile = config.sops.secrets."mqtt/edge/air-sensor/password".path;
                        acl = [ "readwrite apartment/room/air-quality" "readwrite apartment/room/air-quality/#" ];
                    };
                };
            };
        };

        users.users.telemetry-forwarder = {
            isSystemUser = true;
            group = "telemetry-forwarder";
        };
        users.groups.telemetry-forwarder = {};
        systemd.services.telemetry-forwarder = {
            description = "Spool apartment MQTT until homelab PostgreSQL acknowledges it";
            wantedBy = [ "multi-user.target" ];
            after = [ "network-online.target" "mosquitto.service" ];
            wants = [ "network-online.target" ];
            requires = [ "mosquitto.service" ];
            environment = {
                FORWARDER_DB = "/var/lib/telemetry-forwarder/queue.sqlite";
                FORWARDER_LOCAL_USERNAME = "telemetry-forwarder";
                FORWARDER_CLIENT_PREFIX = cfg.clientPrefix;
                FORWARDER_REMOTE_HOST = cfg.remoteHost;
                FORWARDER_LOCAL_PASSWORD_FILE = "%d/local-password";
                FORWARDER_REMOTE_PASSWORD_FILE = "%d/remote-password";
            };
            serviceConfig = {
                ExecStart = "${python}/bin/python -u ${./forwarder.py}";
                LoadCredential = [
                    "local-password:${config.sops.secrets."mqtt/edge/telemetry-forwarder/password".path}"
                    "remote-password:${config.sops.secrets."mqtt/homelab/apartment-bridge/password".path}"
                ];
                User = "telemetry-forwarder";
                Group = "telemetry-forwarder";
                Restart = "always";
                RestartSec = 5;
                StateDirectory = "telemetry-forwarder";
                StateDirectoryMode = "0700";
                NoNewPrivileges = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                PrivateTmp = true;
            };
        };
    };
}
