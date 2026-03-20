{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.desktop.ereader_relay;
in
{
    options.desktop.ereader_relay = {
        enable = mkEnableOption "E-reader BookLore relay proxy";

        port = mkOption {
            type = types.int;
            default = 8033;
            description = "Port to listen on for the relay proxy";
        };

        subdomain = mkOption {
            type = types.str;
            description = "Subdomain prefix for the target host (e.g. books.vm.local)";
        };
    };

    config = mkIf cfg.enable {
        sops.secrets.domain = {
            sopsFile = ../../secrets/shared/selfhost.yaml;
        };

        systemd.services.ereader-relay = {
            description = "E-reader BookLore relay";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];

            preStart = ''
                DOMAIN=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.domain.path})
                TARGET_HOST="${cfg.subdomain}.$DOMAIN"

                ${pkgs.coreutils}/bin/cat > /run/ereader-relay/nginx.conf <<EOF
                worker_processes 1;
                error_log /run/ereader-relay/error.log;
                daemon off;
                pid /run/ereader-relay/nginx.pid;

                events {
                    worker_connections 64;
                }

                http {
                    access_log off;

                    client_body_temp_path /run/ereader-relay/client_body;
                    proxy_temp_path /run/ereader-relay/proxy;
                    fastcgi_temp_path /run/ereader-relay/fastcgi;
                    uwsgi_temp_path /run/ereader-relay/uwsgi;
                    scgi_temp_path /run/ereader-relay/scgi;

                    server {
                        listen ${toString cfg.port};

                        location / {
                            proxy_pass https://$TARGET_HOST;
                            proxy_set_header Host $TARGET_HOST;
                            proxy_ssl_server_name on;
                            proxy_ssl_verify off;
                        }
                    }
                }
                EOF
            '';

            serviceConfig = {
                Type = "simple";
                ExecStart = "${pkgs.nginx}/bin/nginx -e /run/ereader-relay/error.log -c /run/ereader-relay/nginx.conf";
                Restart = "on-failure";
                RestartSec = 5;
                RuntimeDirectory = "ereader-relay";
            };
        };

        networking.firewall.allowedTCPPorts = [ cfg.port ];
    };
}
