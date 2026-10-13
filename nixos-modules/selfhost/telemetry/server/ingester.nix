{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.telemetry.server;
    python = pkgs.python3.withPackages (ps: [ ps.paho-mqtt ps.psycopg ]);
in
{
    config = mkIf cfg.enable {
        sops.secrets."mqtt/homelab/telemetry-ingester/password".restartUnits = [ "mqtt-telemetry-ingester.service" ];

        systemd.services.mqtt-telemetry-ingester = {
            description = "Store MQTT telemetry in PostgreSQL";
            after = [ "mosquitto.service" "telemetry-db-setup.service" ];
            requires = [ "mosquitto.service" "telemetry-db-setup.service" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
                User = "telemetry";
                Group = "telemetry";
                Environment = [
                    "MQTT_HOST=${cfg.listenAddress}"
                    "MQTT_PASSWORD_FILE=%d/mqtt-password"
                ];
                LoadCredential = [ "mqtt-password:${config.sops.secrets."mqtt/homelab/telemetry-ingester/password".path}" ];
                ExecStart = "${python}/bin/python ${./ingest.py}";
                Restart = "always";
                RestartSec = 5;
            };
        };
    };
}
