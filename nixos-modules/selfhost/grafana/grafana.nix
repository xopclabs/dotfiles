{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.grafana;

    telemetry = {
        database = "telemetry";
        databaseUser = "grafana";
        datasource = {
            name = "Telemetry PostgreSQL";
            uid = "telemetry-postgres";
            type = "grafana-postgresql-datasource";
        };
    };

    grafanaSecret = {
        sopsFile = ../../../secrets/shared/selfhost.yaml;
        owner = "grafana";
        group = "grafana";
        mode = "0400";
    };

    dashboards = pkgs.runCommand "grafana-dashboards" {
        nativeBuildInputs = [ pkgs.jq ];
    } ''
        cp -r ${./dashboards} "$out"
        find "$out" -type f -name '*.json' -exec jq empty {} +
    '';

    liveDashboards = "/var/lib/grafana/dashboards";
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
        sops.secrets = {
            "grafana/admin-password" = grafanaSecret;
            "grafana/secret-key" = grafanaSecret;
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
                    prune = true;
                    datasources = [{
                        inherit (telemetry.datasource) name uid type;
                        url = "127.0.0.1:5432";
                        database = telemetry.database;
                        user = telemetry.databaseUser;
                        editable = false;
                        jsonData = {
                            database = telemetry.database;
                            sslmode = "disable";
                            postgresVersion = 1600;
                        };
                    }];
                };
                dashboards.settings = {
                    apiVersion = 1;
                    providers = [{
                        name = "telemetry";
                        type = "file";
                        disableDeletion = false;
                        # UI changes remain live until the next NixOS rebuild, which
                        # reseeds this directory from the versioned JSON files.
                        allowUiUpdates = true;
                        updateIntervalSeconds = 30;
                        options = {
                            path = liveDashboards;
                            foldersFromFilesStructure = true;
                        };
                    }];
                };
            };
        };

        system.activationScripts.grafanaDashboards = {
            deps = [ "users" ];
            text = ''
                staging="$(${pkgs.coreutils}/bin/mktemp -d /var/lib/grafana/.dashboards.XXXXXX)"
                ${pkgs.coreutils}/bin/cp -r ${dashboards}/. "$staging/"
                ${pkgs.coreutils}/bin/chown -R grafana:grafana "$staging"
                ${pkgs.coreutils}/bin/chmod -R u=rwX,g=rX,o= "$staging"
                ${pkgs.coreutils}/bin/rm -rf ${liveDashboards}
                ${pkgs.coreutils}/bin/mv "$staging" ${liveDashboards}
            '';
        };

        systemd.services.grafana = {
            after = [ "telemetry-grafana-db-access.service" ];
            requires = [ "telemetry-grafana-db-access.service" ];
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
