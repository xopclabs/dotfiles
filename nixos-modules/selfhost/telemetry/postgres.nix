{ config, lib, ... }:

with lib;
let
    cfg = config.homelab.telemetry;
in
{
    config = mkIf cfg.enable {
        users.groups.telemetry = {};
        users.users.telemetry = {
            isSystemUser = true;
            group = "telemetry";
        };

        homelab.postgres = {
            enable = true;
            databases = [ "telemetry" ];
            ensureUsers = [
                { name = "telemetry"; }
                {
                    name = "grafana";
                    ensureDBOwnership = false;
                }
            ];
        };

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

        systemd.services.telemetry-grafana-db-access = {
            description = "Grant Grafana read-only access to telemetry";
            after = [ "telemetry-db-setup.service" ];
            requires = [ "telemetry-db-setup.service" ];
            before = [ "grafana.service" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
                Type = "oneshot";
                User = "telemetry";
                RemainAfterExit = true;
            };
            script = ''
                ${config.services.postgresql.package}/bin/psql -d telemetry -v ON_ERROR_STOP=1 <<'SQL'
                GRANT CONNECT ON DATABASE telemetry TO grafana;
                GRANT USAGE ON SCHEMA public TO grafana;
                GRANT SELECT ON ALL TABLES IN SCHEMA public TO grafana;
                ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO grafana;
                SQL
            '';
        };
    };
}
