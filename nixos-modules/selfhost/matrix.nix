{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.matrix;

    synapseRuntimeConfigTemplate = pkgs.writeText "synapse-runtime-config.yaml.tpl" (''
server_name: "$MATRIX_SERVER_NAME"
public_baseurl: "https://$MATRIX_SERVER_NAME"
'' + optionalString cfg.coturn.enable ''
turn_uris:
  - "turn:$MATRIX_SERVER_NAME:${toString cfg.coturn.port}?transport=udp"
  - "turn:$MATRIX_SERVER_NAME:${toString cfg.coturn.port}?transport=tcp"
'' + optionalString cfg.push.enable ''
ip_range_whitelist:
  - "$MATRIX_NTFY_GATEWAY_IP/32"
'');

    elementConfigTemplate = pkgs.writeText "element-config.json.tpl" (builtins.toJSON {
        default_server_config = {
            "m.homeserver" = {
                base_url = "https://$MATRIX_SERVER_NAME";
                server_name = "$MATRIX_SERVER_NAME";
            };
        };
        brand = "Element";
        disable_guests = true;
        disable_3pid_login = true;
        show_labs_settings = false;
    });
in
{
    options.homelab.matrix = {
        enable = mkEnableOption "Matrix Synapse homeserver with Element Web and TURN";

        subdomain = mkOption {
            type = types.str;
            description = "Subdomain for Matrix Synapse (e.g. 'matrix.vm.local')";
        };

        elementSubdomain = mkOption {
            type = types.str;
            description = "Subdomain for Element Web client (e.g. 'element.vm.local')";
        };

        synapsePort = mkOption {
            type = types.int;
            default = 8098;
            description = "Port for Synapse client API listener";
        };

        elementPort = mkOption {
            type = types.int;
            default = 8088;
            description = "Port for Element Web nginx";
        };

        enableRegistration = mkOption {
            type = types.bool;
            default = false;
            description = "Allow public registration (keep false; use registration_shared_secret to create accounts via CLI)";
        };

        maxUploadSize = mkOption {
            type = types.str;
            default = "100M";
            description = "Maximum file upload size";
        };

        coturn = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable coturn TURN server for voice/video calls";
            };

            port = mkOption {
                type = types.int;
                default = 3478;
                description = "STUN/TURN listener port";
            };

            minRelayPort = mkOption {
                type = types.int;
                default = 49000;
                description = "Minimum port for media relay";
            };

            maxRelayPort = mkOption {
                type = types.int;
                default = 50000;
                description = "Maximum port for media relay";
            };

            openFirewall = mkOption {
                type = types.bool;
                default = true;
                description = "Open firewall ports for TURN server";
            };
        };

        push = {
            enable = mkEnableOption ''
                UnifiedPush notifications via a public ntfy push gateway.

                Synapse sends push requests to the configured ntfy server (e.g. on a VPS)
                so mobile clients receive notifications without VPN access to the homeserver.
                Users must configure Element Android to use UnifiedPush with the same ntfy server.
            '';

            ntfySubdomain = mkOption {
                type = types.str;
                default = "ntfy";
                description = ''
                    Subdomain of the public ntfy push gateway (e.g. "ntfy" for ntfy.$DOMAIN).
                '';
            };

            gatewayHost = mkOption {
                type = types.str;
                default = "vps";
                description = ''
                    Hostname label in the sops hosts file for the public ntfy server IP.
                    Used for Synapse ip_range_whitelist.
                '';
            };
        };
    };

    config = mkIf cfg.enable (mkMerge [
        {
            sops.secrets."matrix/synapse-secret" = {
                sopsFile = ../../secrets/shared/selfhost.yaml;
                owner = "matrix-synapse";
                group = "matrix-synapse";
            };

            homelab.postgres.enable = true;

            # Synapse requires C collation; ensureDatabases uses the system default,
            # so we create the database ourselves with the correct locale.
            systemd.services.matrix-synapse-db-setup = {
                description = "Create Matrix Synapse PostgreSQL database with C collation";
                after = [ "postgresql.service" ];
                requires = [ "postgresql.service" ];
                before = [ "matrix-synapse.service" ];
                wantedBy = [ "multi-user.target" ];
                serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                    User = "postgres";
                    ExecStart = pkgs.writeShellScript "matrix-synapse-db-setup" ''
                        set -euo pipefail
                        PSQL="${config.services.postgresql.package}/bin/psql"
                        "$PSQL" -tc "SELECT 1 FROM pg_roles WHERE rolname='matrix-synapse'" | grep -q 1 || \
                            "$PSQL" -c "CREATE USER \"matrix-synapse\""
                        "$PSQL" -tc "SELECT 1 FROM pg_database WHERE datname='matrix-synapse'" | grep -q 1 || \
                            "$PSQL" -c "CREATE DATABASE \"matrix-synapse\" ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' TEMPLATE=template0 OWNER=\"matrix-synapse\""
                    '';
                };
            };
        }

        {
            services.matrix-synapse = {
                enable = true;

                settings = {
                    # Overridden at runtime via extraConfigFiles (needs $DOMAIN from sops env)
                    server_name = "localhost";

                    listeners = [
                        {
                            port = cfg.synapsePort;
                            bind_addresses = [ "127.0.0.1" ];
                            type = "http";
                            tls = false;
                            x_forwarded = true;
                            resources = [
                                {
                                    names = [ "client" "federation" ];
                                    compress = true;
                                }
                            ];
                        }
                    ];

                    database = {
                        name = "psycopg2";
                        args = {
                            host = "/run/postgresql";
                            database = "matrix-synapse";
                            user = "matrix-synapse";
                            cp_min = 5;
                            cp_max = 10;
                        };
                    };

                    enable_registration = cfg.enableRegistration;
                    enable_registration_without_verification = cfg.enableRegistration;

                    url_preview_enabled = true;
                    url_preview_ip_range_blacklist = [
                        "127.0.0.0/8" "10.0.0.0/8" "172.16.0.0/12"
                        "192.168.0.0/16" "100.64.0.0/10" "169.254.0.0/16"
                        "::1/128" "fe80::/10" "fc00::/7"
                    ];

                    trusted_key_servers = [
                        { server_name = "matrix.org"; }
                    ];
                    suppress_key_server_warning = true;

                    max_upload_size = cfg.maxUploadSize;
                    turn_user_lifetime = "1h";
                    turn_allow_guests = false;
                };

                extraConfigFiles = [
                    config.sops.secrets."matrix/synapse-secret".path
                    "/run/matrix-synapse/runtime-config.yaml"
                ];
            };

            systemd.services.matrix-synapse = {
                after = [ "postgresql.service" "matrix-synapse-db-setup.service" ];
                requires = [ "postgresql.service" "matrix-synapse-db-setup.service" ];
                serviceConfig.EnvironmentFile = [ config.sops.secrets."traefik/env".path ];
                serviceConfig.ExecStartPre = mkAfter [
                    (pkgs.writeShellScript "matrix-synapse-runtime-config" ''
                        set -euo pipefail
                        export MATRIX_SERVER_NAME="${cfg.subdomain}.$DOMAIN"
                        ${optionalString cfg.push.enable ''
                        export MATRIX_NTFY_GATEWAY_IP=$(${pkgs.gawk}/bin/awk -v name="${cfg.push.gatewayHost}" '$2 == name { print $1; exit }' ${config.sops.secrets.hosts.path})
                        if [ -z "''${MATRIX_NTFY_GATEWAY_IP:-}" ]; then
                            echo "matrix-synapse: no IP for hosts entry ${cfg.push.gatewayHost}" >&2
                            exit 1
                        fi
                        ''}
                        ${pkgs.envsubst}/bin/envsubst -i "${synapseRuntimeConfigTemplate}" > /run/matrix-synapse/runtime-config.yaml
                    '')
                ];
            };
        }

        {
            services.nginx.virtualHosts."element-web-internal" = {
                listen = [{ addr = "127.0.0.1"; port = cfg.elementPort; }];
                root = "${pkgs.element-web}";
                locations."= /config.json".alias = "/run/element-web/config.json";
                locations."/".tryFiles = "$uri $uri/ /index.html";
            };

            systemd.services.element-web-config = {
                description = "Generate Element Web configuration";
                after = [ "network.target" ];
                wantedBy = [ "multi-user.target" ];
                before = [ "nginx.service" ];
                serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                    RuntimeDirectory = "element-web";
                    RuntimeDirectoryPreserve = "yes";
                    EnvironmentFile = config.sops.secrets."traefik/env".path;
                    ExecStart = pkgs.writeShellScript "element-web-config" ''
                        set -euo pipefail
                        export MATRIX_SERVER_NAME="${cfg.subdomain}.$DOMAIN"
                        ${pkgs.envsubst}/bin/envsubst -i "${elementConfigTemplate}" > /run/element-web/config.json
                    '';
                };
            };

            systemd.services.nginx = {
                after = [ "element-web-config.service" ];
                wants = [ "element-web-config.service" ];
            };
        }

        (mkIf cfg.coturn.enable {
            sops.secrets."matrix/coturn-secret" = {
                sopsFile = ../../secrets/shared/selfhost.yaml;
            };

            users.users.turnserver = {
                isSystemUser = true;
                group = "turnserver";
            };
            users.groups.turnserver = {};

            systemd.services.coturn = {
                description = "Coturn TURN server for Matrix voice/video calls";
                after = [ "network-online.target" ];
                wants = [ "network-online.target" ];
                wantedBy = [ "multi-user.target" ];

                serviceConfig = {
                    Type = "simple";
                    User = "turnserver";
                    Group = "turnserver";
                    RuntimeDirectory = "coturn";
                    ExecStartPre = [
                        "+${pkgs.writeShellScript "coturn-generate-config" ''
                            set -euo pipefail
                            TURN_SECRET=$(cat ${config.sops.secrets."matrix/coturn-secret".path})
                            {
                                echo "listening-port=${toString cfg.coturn.port}"
                                echo "min-port=${toString cfg.coturn.minRelayPort}"
                                echo "max-port=${toString cfg.coturn.maxRelayPort}"
                                echo "use-auth-secret"
                                printf 'static-auth-secret=%s\n' "$TURN_SECRET"
                                echo "realm=turn.local"
                                echo "no-tls"
                                echo "no-dtls"
                                echo "no-cli"
                                echo "fingerprint"
                                echo "log-file=stdout"
                            } > /run/coturn/turnserver.conf
                            chown turnserver:turnserver /run/coturn/turnserver.conf
                            chmod 600 /run/coturn/turnserver.conf
                        ''}"
                    ];
                    ExecStart = "${pkgs.coturn}/bin/turnserver -c /run/coturn/turnserver.conf";
                    Restart = "on-failure";
                    RestartSec = "5s";
                    LimitNOFILE = 65536;
                };
            };

            networking.firewall = mkIf cfg.coturn.openFirewall {
                allowedTCPPorts = [ cfg.coturn.port ];
                allowedUDPPorts = [ cfg.coturn.port ];
                allowedUDPPortRanges = [
                    { from = cfg.coturn.minRelayPort; to = cfg.coturn.maxRelayPort; }
                ];
            };
        })

        (mkIf config.homelab.traefik.enable {
            homelab.traefik.routes = [
                {
                    name = "matrix-synapse";
                    subdomain = cfg.subdomain;
                    backendUrl = "http://127.0.0.1:${toString cfg.synapsePort}";
                }
                {
                    name = "element-web";
                    subdomain = cfg.elementSubdomain;
                    backendUrl = "http://127.0.0.1:${toString cfg.elementPort}";
                }
            ];
        })

        (mkIf config.homelab.glance.enable {
            homelab.glance.services = [
                {
                    title = "Element";
                    subdomain = cfg.elementSubdomain;
                    icon = "si:element";
                    group = "Services";
                }
            ];
        })
    ]);
}
