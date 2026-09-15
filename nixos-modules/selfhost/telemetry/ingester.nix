{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.telemetry;
    python = pkgs.python3.withPackages (ps: [ ps.paho-mqtt ps.psycopg ]);
in
{
    config = mkIf cfg.enable {
        systemd.services.telemetry-db-setup = {
            description = "Create MQTT telemetry schema";
            after = [ "postgresql.service" "postgresql-setup.service" ];
            requires = [ "postgresql.service" "postgresql-setup.service" ];
            before = [ "mqtt-telemetry-ingester.service" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
                Type = "oneshot";
                User = "telemetry";
                RemainAfterExit = true;
            };
            script = ''
                ${config.services.postgresql.package}/bin/psql -v ON_ERROR_STOP=1 <<'SQL'
                CREATE TABLE IF NOT EXISTS mqtt_messages (
                    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                    received_at timestamptz NOT NULL DEFAULT now(),
                    topic text NOT NULL,
                    payload jsonb,
                    payload_text text,
                    qos smallint NOT NULL CHECK (qos BETWEEN 0 AND 2),
                    retained boolean NOT NULL,
                    CHECK ((payload IS NULL) <> (payload_text IS NULL))
                );
                CREATE INDEX IF NOT EXISTS mqtt_messages_topic_received_idx ON mqtt_messages (topic, received_at DESC);
                CREATE INDEX IF NOT EXISTS mqtt_messages_received_idx ON mqtt_messages (received_at DESC);
                SQL
            '';
        };

        systemd.services.mqtt-telemetry-ingester = {
            description = "Store MQTT telemetry in PostgreSQL";
            after = [ "mosquitto.service" "telemetry-db-setup.service" ];
            requires = [ "mosquitto.service" "telemetry-db-setup.service" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
                User = "telemetry";
                Group = "telemetry";
                Environment = [
                    "MQTT_HOST=10.250.250.1"
                    "MQTT_PASSWORD_FILE=${config.sops.secrets."mqtt/homelab/telemetry-ingester/password".path}"
                ];
                ExecStart = "${python}/bin/python ${./ingest.py}";
                Restart = "always";
                RestartSec = 5;
            };
        };
    };
}
