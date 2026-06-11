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

    # Rule-sets for smart routing (Russian IPs / sites stay on the local
    # connection; everything else exits through the Reality tunnel).
    rulesetDir = "/var/lib/sing-box-reality/rule-sets";
    geositeUrl = "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ru.srs";
    geoipUrl = "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-ru.srs";

    # Hysteria2 (QUIC) exit transport. Self-signed cert lives in the server's
    # state dir (regenerated only if missing); the client trusts it via SNI +
    # `insecure` since the real auth/stealth is the password + Salamander obfs.
    hysteriaStateDir = "/var/lib/sing-box-hysteria";
    hysteriaRunDir = "/run/sing-box-hysteria";
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
                default = 10808;
                description = ''
                    Local mixed (SOCKS5 + HTTP) inbound port for the Reality tunnel,
                    bound to 127.0.0.1 only. Smart-routed: Russian IPs/sites and the
                    configured direct domains egress locally; everything else exits
                    through the Reality tunnel to the VPS.
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

            proxychains = {
                enable = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Configure system proxychains to use this Reality proxy.";
                };
            };

            updateInterval = mkOption {
                type = types.str;
                default = "daily";
                description = ''
                    How often to refresh the geo rule-sets and rebuild the client
                    config (systemd calendar format).
                '';
            };
        };

        hysteria2 = {
            enable = mkEnableOption ''
                Hysteria2 (QUIC) as the proxy exit transport instead of VLESS+Reality
                over TCP. Hysteria2 uses a UDP/QUIC datagram tunnel with the Brutal
                congestion controller and Salamander obfuscation, which is far more
                resistant to the volumetric DPI throttling that chokes TCP-based
                Reality connections crossing the Russian border. Enable on BOTH the
                server (VPS) and the client (homelab); the Reality server keeps
                running on TCP :443 as a fallback / Traefik front
            '';

            port = mkOption {
                type = types.port;
                default = 443;
                description = ''
                    UDP port the Hysteria2 server listens on and the client dials.
                    Independent of the Reality TCP :443 listener (different protocol).
                '';
            };

            upMbps = mkOption {
                type = types.int;
                default = 50;
                description = ''
                    Client uplink bandwidth in Mbps advertised to the Brutal
                    congestion controller. Set close to the real upload capacity of
                    the homelab line; too high causes loss, too low caps throughput.
                '';
            };

            downMbps = mkOption {
                type = types.int;
                default = 150;
                description = ''
                    Client downlink bandwidth in Mbps for the Brutal congestion
                    controller. Set close to the real download capacity of the
                    homelab line.
                '';
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

        # ---- Hysteria2 shared secrets (auth password + Salamander obfs) ----
        (mkIf (cfg.hysteria2.enable && (cfg.server.enable || cfg.client.enable)) {
            sops.secrets = {
                "reality/hysteria_password".sopsFile = ../../secrets/shared/selfhost.yaml;
                "reality/hysteria_obfs".sopsFile = ../../secrets/shared/selfhost.yaml;
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

        # ---- Hysteria2 server (sing-box, QUIC/UDP exit on the VPS) ----
        (mkIf (cfg.server.enable && cfg.hysteria2.enable) {
            systemd.services.sing-box-hysteria-config = {
                description = "Render Hysteria2 server config + self-signed cert from secrets";
                before = [ "sing-box-hysteria.service" ];
                requiredBy = [ "sing-box-hysteria.service" ];
                wantedBy = [ "multi-user.target" ];
                path = with pkgs; [ jq gawk coreutils sing-box ];
                serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                    StateDirectory = "sing-box-hysteria";
                };
                script = ''
                    set -euo pipefail
                    umask 077
                    mkdir -p ${hysteriaRunDir} ${hysteriaStateDir}

                    SNI="${cfg.maskSubdomain}.$(cat ${domainPath})"

                    # Self-signed keypair, generated once and reused (the client
                    # trusts it via SNI + insecure, so it just needs to be stable).
                    if [ ! -s ${hysteriaStateDir}/cert.pem ] || [ ! -s ${hysteriaStateDir}/key.pem ]; then
                        sing-box generate tls-keypair "$SNI" -m 120 > ${hysteriaStateDir}/keypair.pem
                        awk '/BEGIN PRIVATE KEY/,/END PRIVATE KEY/' ${hysteriaStateDir}/keypair.pem > ${hysteriaStateDir}/key.pem
                        awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/' ${hysteriaStateDir}/keypair.pem > ${hysteriaStateDir}/cert.pem
                        rm -f ${hysteriaStateDir}/keypair.pem
                    fi

                    HY_PASSWORD=$(cat ${config.sops.secrets."reality/hysteria_password".path})
                    HY_OBFS=$(cat ${config.sops.secrets."reality/hysteria_obfs".path})

                    jq -n \
                        --arg port "${toString cfg.hysteria2.port}" \
                        --arg password "$HY_PASSWORD" \
                        --arg obfs "$HY_OBFS" \
                        --arg cert "${hysteriaStateDir}/cert.pem" \
                        --arg key "${hysteriaStateDir}/key.pem" \
                        '{
                            log: { level: "warn" },
                            inbounds: [
                                {
                                    type: "hysteria2",
                                    tag: "hysteria2-in",
                                    listen: "::",
                                    listen_port: ($port | tonumber),
                                    users: [ { password: $password } ],
                                    obfs: { type: "salamander", password: $obfs },
                                    tls: { enabled: true, alpn: [ "h3" ], certificate_path: $cert, key_path: $key }
                                }
                            ],
                            outbounds: [
                                { type: "direct", tag: "direct" },
                                { type: "block", tag: "block" }
                            ],
                            route: {
                                rules: [ { protocol: [ "bittorrent" ], outbound: "block" } ]
                            }
                        }' > ${hysteriaRunDir}/config.json

                    sing-box check -c ${hysteriaRunDir}/config.json
                '';
            };

            systemd.services.sing-box-hysteria = {
                description = "Hysteria2 server (QUIC exit)";
                documentation = [ "https://sing-box.sagernet.org" ];
                after = [ "network-online.target" "sing-box-hysteria-config.service" ];
                requires = [ "sing-box-hysteria-config.service" ];
                wants = [ "network-online.target" ];
                wantedBy = [ "multi-user.target" ];
                serviceConfig = {
                    Type = "simple";
                    User = "root";
                    StateDirectory = "sing-box-hysteria";
                    WorkingDirectory = hysteriaStateDir;
                    ExecStart = "${pkgs.sing-box}/bin/sing-box -D ${hysteriaStateDir} -c ${hysteriaRunDir}/config.json run";
                    Restart = "on-failure";
                    RestartSec = "5s";
                };
            };

            networking.firewall.allowedUDPPorts = [ cfg.hysteria2.port ];

            sops.secrets."reality/hysteria_password".restartUnits = [ "sing-box-hysteria-config.service" "sing-box-hysteria.service" ];
            sops.secrets."reality/hysteria_obfs".restartUnits = [ "sing-box-hysteria-config.service" "sing-box-hysteria.service" ];
        })

        # ---- Reality client (dedicated sing-box instance) ----
        (mkIf cfg.client.enable {
            sops.secrets = {
                "reality/public_key".sopsFile = ../../secrets/shared/selfhost.yaml;
                "smart_routing/direct-domains" = {
                    sopsFile = ../../secrets/shared/selfhost.yaml;
                    restartUnits = [ "sing-box-reality-config.service" ];
                };
            };

            environment.systemPackages = with pkgs; [ sing-box ];

            systemd.services.sing-box-reality-config = {
                description = "Build sing-box Reality client config (geo routing + secrets)";
                restartIfChanged = false;
                before = [ "sing-box-reality.service" ];
                requiredBy = [ "sing-box-reality.service" ];
                wantedBy = [ "multi-user.target" ];
                after = [ "network-online.target" ];
                wants = [ "network-online.target" ];
                path = with pkgs; [ jq curl coreutils gnugrep sing-box systemd ];
                serviceConfig.Type = "oneshot";
                script = ''
                    set -uo pipefail
                    umask 077
                    mkdir -p /run/sing-box-reality ${rulesetDir}

                    # Refresh geo rule-sets (best effort; missing ones are simply
                    # omitted from routing so the config stays valid).
                    curl -fsSL --connect-timeout 10 --max-time 60 \
                        -o "${rulesetDir}/geosite-category-ru.srs" "${geositeUrl}" \
                        || echo "WARNING: could not download geosite-category-ru.srs"
                    curl -fsSL --connect-timeout 10 --max-time 60 \
                        -o "${rulesetDir}/geoip-ru.srs" "${geoipUrl}" \
                        || echo "WARNING: could not download geoip-ru.srs"

                    HAVE_GEOSITE=false; [ -f "${rulesetDir}/geosite-category-ru.srs" ] && HAVE_GEOSITE=true
                    HAVE_GEOIP=false; [ -f "${rulesetDir}/geoip-ru.srs" ] && HAVE_GEOIP=true

                    REALITY_UUID=$(cat ${uuidPath})
                    REALITY_PUBLIC_KEY=$(cat ${config.sops.secrets."reality/public_key".path})
                    REALITY_SHORT_ID=$(cat ${shortIdPath})
                    SERVER_NAME="${cfg.maskSubdomain}.$(cat ${domainPath})"
                    ENDPOINT="${optionalString (cfg.client.serverEndpoint != null) cfg.client.serverEndpoint}"
                    [ -n "$ENDPOINT" ] || ENDPOINT="$SERVER_NAME"

                    HY_PASSWORD=""
                    HY_OBFS=""
                    ${optionalString cfg.hysteria2.enable ''
                        HY_PASSWORD=$(cat ${config.sops.secrets."reality/hysteria_password".path})
                        HY_OBFS=$(cat ${config.sops.secrets."reality/hysteria_obfs".path})
                    ''}

                    CUSTOM_DOMAINS=$(cat ${config.sops.secrets."smart_routing/direct-domains".path} \
                        | grep -v '^#' | grep -v '^$' | jq -R . | jq -s .) || CUSTOM_DOMAINS='[]'

                    jq -n \
                        --arg listen_port "${toString cfg.client.listenPort}" \
                        --arg server "$ENDPOINT" \
                        --arg server_port "${toString cfg.client.serverPort}" \
                        --arg uuid "$REALITY_UUID" \
                        --arg server_name "$SERVER_NAME" \
                        --arg public_key "$REALITY_PUBLIC_KEY" \
                        --arg short_id "$REALITY_SHORT_ID" \
                        --arg ruleset_dir "${rulesetDir}" \
                        --argjson custom_domains "$CUSTOM_DOMAINS" \
                        --argjson have_geoip "$HAVE_GEOIP" \
                        --argjson have_geosite "$HAVE_GEOSITE" \
                        --argjson use_hysteria ${if cfg.hysteria2.enable then "true" else "false"} \
                        --arg hy_port "${toString cfg.hysteria2.port}" \
                        --arg hy_up "${toString cfg.hysteria2.upMbps}" \
                        --arg hy_down "${toString cfg.hysteria2.downMbps}" \
                        --arg hy_password "$HY_PASSWORD" \
                        --arg hy_obfs "$HY_OBFS" \
                        '{
                            log: { level: "warn" },
                            inbounds: [
                                { type: "mixed", tag: "mixed-in", listen: "127.0.0.1", listen_port: ($listen_port | tonumber) }
                            ],
                            outbounds: (
                                [
                                    {
                                        type: "vless",
                                        tag: "reality-out",
                                        server: $server,
                                        server_port: ($server_port | tonumber),
                                        uuid: $uuid,
                                        flow: "xtls-rprx-vision",
                                        tls: {
                                            enabled: true,
                                            server_name: $server_name,
                                            utls: { enabled: true, fingerprint: "chrome" },
                                            reality: { enabled: true, public_key: $public_key, short_id: $short_id }
                                        }
                                    }
                                ]
                                + (if $use_hysteria then [
                                    {
                                        type: "hysteria2",
                                        tag: "hysteria2-out",
                                        server: $server,
                                        server_port: ($hy_port | tonumber),
                                        up_mbps: ($hy_up | tonumber),
                                        down_mbps: ($hy_down | tonumber),
                                        password: $hy_password,
                                        obfs: { type: "salamander", password: $hy_obfs },
                                        tls: { enabled: true, server_name: $server_name, insecure: true, alpn: [ "h3" ] }
                                    }
                                ] else [] end)
                                + [ { type: "direct", tag: "direct" } ]
                            ),
                            route: {
                                rule_set: (
                                    (if $have_geosite then [{ tag: "category-ru", type: "local", format: "binary", path: ($ruleset_dir + "/geosite-category-ru.srs") }] else [] end)
                                    + (if $have_geoip then [{ tag: "geoip-ru", type: "local", format: "binary", path: ($ruleset_dir + "/geoip-ru.srs") }] else [] end)
                                ),
                                rules: (
                                    [ { inbound: "mixed-in", action: "sniff" } ]
                                    + (if ($custom_domains | length) > 0 then [{ domain: $custom_domains, outbound: "direct" }] else [] end)
                                    + [ { ip_is_private: true, outbound: "direct" } ]
                                    + (if $have_geoip then [{ rule_set: "geoip-ru", outbound: "direct" }] else [] end)
                                    + (if $have_geosite then [{ rule_set: "category-ru", outbound: "direct" }] else [] end)
                                ),
                                final: (if $use_hysteria then "hysteria2-out" else "reality-out" end),
                                auto_detect_interface: true
                            }
                        }' > /run/sing-box-reality/config.json

                    if ! sing-box check -c /run/sing-box-reality/config.json; then
                        if [ -f /var/lib/sing-box-reality/config.json.prev ]; then
                            echo "WARNING: new config invalid; restoring previous"
                            cp /var/lib/sing-box-reality/config.json.prev /run/sing-box-reality/config.json
                        else
                            echo "WARNING: new config invalid and no previous config to restore"
                            exit 1
                        fi
                    else
                        cp /run/sing-box-reality/config.json /var/lib/sing-box-reality/config.json.prev
                    fi

                    # Non-blocking reload only when already running (timer refresh);
                    # on boot, sing-box-reality starts after this unit via Requires=.
                    if systemctl is-active --quiet sing-box-reality.service; then
                        systemctl --no-block try-restart sing-box-reality.service || true
                    fi
                    exit 0
                '';
            };

            systemd.timers.sing-box-reality-config = {
                description = "Refresh sing-box Reality client geo rule-sets";
                wantedBy = [ "timers.target" ];
                timerConfig = {
                    OnCalendar = cfg.client.updateInterval;
                    OnBootSec = "2min";
                    Persistent = true;
                    Unit = "sing-box-reality-config.service";
                };
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

            programs.proxychains = mkIf cfg.client.proxychains.enable {
                enable = true;
                quietMode = true;
                proxies.reality = {
                    enable = true;
                    type = "socks5";
                    host = "127.0.0.1";
                    port = cfg.client.listenPort;
                };
            };

            sops.secrets."reality/public_key".restartUnits = [ "sing-box-reality-config.service" "sing-box-reality.service" ];
            sops.secrets."reality/uuid".restartUnits = [ "sing-box-reality-config.service" "sing-box-reality.service" ];
            sops.secrets."reality/short_id".restartUnits = [ "sing-box-reality-config.service" "sing-box-reality.service" ];
        })

        # ---- Rebuild + restart the client when Hysteria2 secrets rotate ----
        (mkIf (cfg.client.enable && cfg.hysteria2.enable) {
            sops.secrets."reality/hysteria_password".restartUnits = [ "sing-box-reality-config.service" "sing-box-reality.service" ];
            sops.secrets."reality/hysteria_obfs".restartUnits = [ "sing-box-reality-config.service" "sing-box-reality.service" ];
        })
    ];
}
