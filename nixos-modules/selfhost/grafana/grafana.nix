{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.grafana;
    dashboardPath = pkgs.runCommand "grafana-dashboards" {} ''
        mkdir -p "$out"
        cp ${./dashboards/shelly-power.json} "$out/shelly-power.json"
    '';
in
{
    options.homelab.grafana = {
        enable = mkEnableOption "Grafana telemetry dashboards";

        subdomain = mkOption {
            type = types.str;
            description = "Subdomain for Grafana";
        };

        port = mkOption {
            type = types.port;
            default = 3000;
            description = "Local Grafana HTTP port";
        };
    };

    config = mkIf cfg.enable {
        homelab.postgres.ensureUsers = [{
            name = "grafana";
            ensureDBOwnership = false;
        }];

        sops.secrets = {
            "grafana/admin-password" = {
                sopsFile = ../../../secrets/shared/selfhost.yaml;
                owner = "grafana";
                group = "grafana";
                mode = "0400";
            };
            "grafana/secret-key" = {
                sopsFile = ../../../secrets/shared/selfhost.yaml;
                owner = "grafana";
                group = "grafana";
                mode = "0400";
            };
        };

        services.grafana = {
            enable = true;
            settings = {
                server = {
                    http_addr = "127.0.0.1";
                    http_port = cfg.port;
                    domain = cfg.subdomain;
                    root_url = "https://${cfg.subdomain}";
                };
                security = {
                    admin_user = "admin";
                    admin_password = "$__file{${config.sops.secrets."grafana/admin-password".path}}";
                    secret_key = "$__file{${config.sops.secrets."grafana/secret-key".path}}";
                    cookie_secure = true;
                };
                users = {
                    allow_sign_up = false;
                    allow_org_create = false;
                };
            };
            provision = {
                datasources.settings = {
                    apiVersion = 1;
                    datasources = [{
                        name = "Telemetry PostgreSQL";
                        uid = "telemetry-postgres";
                        type = "grafana-postgresql-datasource";
                        url = "127.0.0.1:5432";
                        database = "telemetry";
                        user = "grafana";
                        editable = false;
                        jsonData = {
                            database = "telemetry";
                            sslmode = "disable";
                            postgresVersion = 1600;
                        };
                    }];
                };
                dashboards.settings.providers = [{
                    name = "telemetry";
                    options.path = dashboardPath;
                }];
            };
        };

        systemd.services.grafana-db-access = {
            description = "Grant Grafana read-only telemetry access";
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

        systemd.services.grafana = {
            after = [ "grafana-db-access.service" ];
            requires = [ "grafana-db-access.service" ];
        };

        homelab.traefik.routes = mkIf config.homelab.traefik.enable [{
            name = "grafana";
            subdomain = cfg.subdomain;
            backendUrl = "http://127.0.0.1:${toString cfg.port}";
        }];

        homelab.glance.services = mkIf config.homelab.glance.enable [{
            title = "Grafana";
            subdomain = cfg.subdomain;
            icon = "si:grafana";
            group = "Services";
        }];
    };
}
