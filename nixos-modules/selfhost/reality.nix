{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.reality;

    # Loopback port Traefik's HTTPS entrypoint moves to when the Reality server
    # is enabled. Xray owns the public :443 and relays all non-Reality TLS here
    # (with PROXY protocol so Traefik still sees the real client IP).
    fallbackPort = cfg.fallbackPort;

    domainPath = config.sops.secrets."domain".path;
    uuidPath = config.sops.secrets."reality/uuid".path;
    shortIdPath = config.sops.secrets."reality/short_id".path;

    # Xray VLESS+Reality+Vision server config template. Secrets and the
    # masquerade server name are substituted at runtime via envsubst so they
    # never enter the Nix store.
    serverTemplate = pkgs.writeText "xray-reality.json.tmpl" ''
        {
          "log": { "loglevel": "warning" },
          "inbounds": [
            {
              "tag": "vless-reality",
              "listen": "0.0.0.0",
              "port": ${toString cfg.server.listenPort},
              "protocol": "vless",
              "settings": {
                "clients": [
                  { "id": "''${REALITY_UUID}", "flow": "xtls-rprx-vision" }
                ],
                "decryption": "none"
              },
              "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                  "show": false,
                  "dest": "127.0.0.1:${toString fallbackPort}",
                  "xver": 1,
                  "serverNames": [ "''${REALITY_SERVER_NAME}" ],
                  "privateKey": "''${REALITY_PRIVATE_KEY}",
                  "shortIds": [ "''${REALITY_SHORT_ID}" ]
                }
              },
              "sniffing": {
                "enabled": true,
                "destOverride": [ "http", "tls", "quic" ],
                "routeOnly": true
              }
            }
          ],
          "outbounds": [
            { "protocol": "freedom", "tag": "direct", "settings": { "domainStrategy": "UseIPv4" } },
            { "protocol": "blackhole", "tag": "block" }
          ],
          "routing": {
            "domainStrategy": "IPIfNonMatch",
            "rules": [
              { "type": "field", "protocol": [ "bittorrent" ], "outboundTag": "block" }
            ]
          }
        }
    '';

    # sing-box client config template (homelab). Routes all traffic through the
    # Reality tunnel to the VPS exit; private ranges stay direct.
    clientTemplate = pkgs.writeText "sing-box-reality.json.tmpl" ''
        {
          "log": { "level": "warn" },
          "inbounds": [
            {
              "type": "mixed",
              "tag": "mixed-in",
              "listen": "127.0.0.1",
              "listen_port": ${toString cfg.client.listenPort}
            }
          ],
          "outbounds": [
            {
              "type": "vless",
              "tag": "reality-out",
              "server": "''${REALITY_SERVER_ENDPOINT}",
              "server_port": ${toString cfg.client.serverPort},
              "uuid": "''${REALITY_UUID}",
              "flow": "xtls-rprx-vision",
              "tls": {
                "enabled": true,
                "server_name": "''${REALITY_SERVER_NAME}",
                "utls": { "enabled": true, "fingerprint": "chrome" },
                "reality": {
                  "enabled": true,
                  "public_key": "''${REALITY_PUBLIC_KEY}",
                  "short_id": "''${REALITY_SHORT_ID}"
                }
              }
            },
            { "type": "direct", "tag": "direct" }
          ],
          "route": {
            "rules": [
              { "inbound": "mixed-in", "action": "sniff" },
              { "ip_is_private": true, "outbound": "direct" }
            ],
            "final": "reality-out",
            "auto_detect_interface": true
          }
        }
    '';
in
{
    options.homelab.reality = {
        maskSubdomain = mkOption {
            type = types.str;
            default = "vaultwarden";
            description = ''
                Subdomain (under the configured $DOMAIN) whose genuine HTTPS site
                Reality mimics. The Xray server borrows this site's TLS handshake
                via the real Traefik backend, and the sing-box client presents it
                as SNI. Defaults to "vaultwarden".
            '';
        };

        fallbackPort = mkOption {
            type = types.port;
            default = 8443;
            description = ''
                Loopback port that Traefik's HTTPS (websecure) entrypoint binds to
                when the Reality server is enabled. Xray relays all non-Reality TLS
                here over PROXY protocol, so existing public services keep working
                with their real certificates and Traefik still sees client IPs.
            '';
        };

        server = {
            enable = mkEnableOption "Xray VLESS+Reality (XTLS-Vision) server on the public :443";

            listenPort = mkOption {
                type = types.port;
                default = 443;
                description = "Public TCP port for the Reality inbound.";
            };
        };

        client = {
            enable = mkEnableOption "Dedicated sing-box Reality client exposing a local SOCKS/HTTP proxy";

            listenPort = mkOption {
                type = types.port;
                default = 10810;
                description = ''
                    Local mixed (SOCKS5 + HTTP) inbound port for the Reality tunnel.
                    Bound to 127.0.0.1 only. Distinct from desktop.singbox (10808)
                    so both can run side by side.
                '';
            };

            serverEndpoint = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = ''
                    Host the client dials for the Reality server. Defaults to
                    `<maskSubdomain>.$DOMAIN` (which resolves to the VPS public IP).
                    Set to a literal IP to bypass local/split-horizon DNS.
                '';
            };

            serverPort = mkOption {
                type = types.port;
                default = 443;
                description = "Port the client dials for the Reality server.";
            };
        };
    };

    config = mkMerge [
        # ---- Shared secrets (server and/or client) ----
        (mkIf (cfg.server.enable || cfg.client.enable) {
            sops.secrets = {
                "domain".sopsFile = ../../secrets/shared/selfhost.yaml;
                "reality/uuid".sopsFile = ../../secrets/shared/selfhost.yaml;
                "reality/short_id".sopsFile = ../../secrets/shared/selfhost.yaml;
            };
        })

        # ---- Reality server (Xray on the public :443) ----
        (mkIf cfg.server.enable {
            assertions = [{
                assertion = config.homelab.traefik.enable;
                message = "homelab.reality.server requires homelab.traefik.enable (Reality forwards non-proxy TLS to Traefik).";
            }];

            sops.secrets."reality/private_key".sopsFile = ../../secrets/shared/selfhost.yaml;

            # Move Traefik's HTTPS entrypoint to loopback and have it trust the
            # PROXY protocol header Xray prepends (xver: 1) so real client IPs
            # survive for IP whitelisting and fail2ban.
            homelab.traefik.websecureAddress = "127.0.0.1:${toString fallbackPort}";
            homelab.traefik.proxyProtocolTrustedIPs = [ "127.0.0.1/32" ];

            services.xray = {
                enable = true;
                settingsFile = "/run/xray/config.json";
            };

            systemd.services.reality-server-config = {
                description = "Render Xray Reality server config from secrets";
                before = [ "xray.service" ];
                requiredBy = [ "xray.service" ];
                wantedBy = [ "multi-user.target" ];
                serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                };
                script = ''
                    set -euo pipefail
                    umask 077
                    mkdir -p /run/xray
                    export REALITY_UUID=$(${pkgs.coreutils}/bin/cat ${uuidPath})
                    export REALITY_PRIVATE_KEY=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."reality/private_key".path})
                    export REALITY_SHORT_ID=$(${pkgs.coreutils}/bin/cat ${shortIdPath})
                    export REALITY_SERVER_NAME="${cfg.maskSubdomain}.$(${pkgs.coreutils}/bin/cat ${domainPath})"
                    ${pkgs.envsubst}/bin/envsubst \
                        '$REALITY_UUID $REALITY_PRIVATE_KEY $REALITY_SHORT_ID $REALITY_SERVER_NAME' \
                        < ${serverTemplate} > /run/xray/config.json
                    ${config.services.xray.package}/bin/xray -test -config /run/xray/config.json
                '';
            };

            systemd.services.xray = {
                after = [ "reality-server-config.service" ];
                requires = [ "reality-server-config.service" ];
            };

            # Regenerate + restart when secrets rotate.
            sops.secrets."reality/private_key".restartUnits = [ "reality-server-config.service" "xray.service" ];
            sops.secrets."reality/uuid".restartUnits = [ "reality-server-config.service" "xray.service" ];
            sops.secrets."reality/short_id".restartUnits = [ "reality-server-config.service" "xray.service" ];

            networking.firewall.allowedTCPPorts = [ cfg.server.listenPort ];
        })

        # ---- Reality client (dedicated sing-box instance) ----
        (mkIf cfg.client.enable {
            sops.secrets."reality/public_key".sopsFile = ../../secrets/shared/selfhost.yaml;

            systemd.services.sing-box-reality-config = {
                description = "Render sing-box Reality client config from secrets";
                before = [ "sing-box-reality.service" ];
                requiredBy = [ "sing-box-reality.service" ];
                wantedBy = [ "multi-user.target" ];
                serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                };
                script = ''
                    set -euo pipefail
                    umask 077
                    mkdir -p /run/sing-box-reality
                    export REALITY_UUID=$(${pkgs.coreutils}/bin/cat ${uuidPath})
                    export REALITY_PUBLIC_KEY=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."reality/public_key".path})
                    export REALITY_SHORT_ID=$(${pkgs.coreutils}/bin/cat ${shortIdPath})
                    export REALITY_SERVER_NAME="${cfg.maskSubdomain}.$(${pkgs.coreutils}/bin/cat ${domainPath})"
                    export REALITY_SERVER_ENDPOINT="${
                        if cfg.client.serverEndpoint != null
                        then cfg.client.serverEndpoint
                        else "$REALITY_SERVER_NAME"
                    }"
                    ${pkgs.envsubst}/bin/envsubst \
                        '$REALITY_UUID $REALITY_PUBLIC_KEY $REALITY_SHORT_ID $REALITY_SERVER_NAME $REALITY_SERVER_ENDPOINT' \
                        < ${clientTemplate} > /run/sing-box-reality/config.json
                    ${pkgs.sing-box}/bin/sing-box check -c /run/sing-box-reality/config.json
                '';
            };

            systemd.services.sing-box-reality = {
                description = "sing-box Reality client (VPS exit)";
                documentation = [ "https://sing-box.sagernet.org" ];
                after = [ "network-online.target" "sing-box-reality-config.service" ];
                requires = [ "sing-box-reality-config.service" ];
                wants = [ "network-online.target" ];
                wantedBy = [ "multi-user.target" ];
                serviceConfig = {
                    Type = "simple";
                    User = "root";
                    StateDirectory = "sing-box-reality";
                    WorkingDirectory = "/var/lib/sing-box-reality";
                    ExecStart = "${pkgs.sing-box}/bin/sing-box -D /var/lib/sing-box-reality -c /run/sing-box-reality/config.json run";
                    Restart = "on-failure";
                    RestartSec = "5s";
                };
            };

            sops.secrets."reality/public_key".restartUnits = [ "sing-box-reality-config.service" "sing-box-reality.service" ];
            sops.secrets."reality/uuid".restartUnits = [ "sing-box-reality-config.service" "sing-box-reality.service" ];
            sops.secrets."reality/short_id".restartUnits = [ "sing-box-reality-config.service" "sing-box-reality.service" ];
        })
    ];
}
