{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.desktop.singbox;

    moduleDir = ./singbox;
    convertScript = "${moduleDir}/convert-xray-outbound.jq";
    buildScript = "${moduleDir}/build-config.jq";

    convertSubscription = tag: file: ''
        if [ -f '${file}' ]; then
            PROXY=$(${pkgs.jq}/bin/jq -c '.outbounds[] | select(.tag == "proxy")' '${file}' | head -n1)
            if [ -n "$PROXY" ]; then
                CONVERTED=$(${pkgs.jq}/bin/jq -c -f ${convertScript} --arg tag '${tag}' <<< "$PROXY")
                if [ -n "$CONVERTED" ]; then
                    SUB_OUTBOUNDS=$(echo "$SUB_OUTBOUNDS" | ${pkgs.jq}/bin/jq -c --argjson item "$CONVERTED" '. + [$item]')
                    SUB_TAGS=$(echo "$SUB_TAGS" | ${pkgs.jq}/bin/jq -c --arg tag '${tag}' '. + [$tag]')
                fi
            else
                echo "WARNING: no proxy outbound in ${file}"
            fi
        fi
    '';
in
{
    options.desktop.singbox = {
        enable = mkEnableOption "sing-box proxy with geo routing and urltest failover";

        listenPort = mkOption {
            type = types.port;
            default = 10808;
            description = "Local mixed (SOCKS+HTTP) inbound port.";
        };

        outbounds = {
            wg = {
                enable = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Include WireGuard client interface as a urltest outbound.";
                };
                bindInterface = mkOption {
                    type = types.str;
                    default = "wg-vps";
                    description = "Existing WireGuard client interface for VPS egress.";
                };
                bindAddress = mkOption {
                    type = types.str;
                    default = "";
                    description = "Optional tunnel source address for VPS egress (e.g. 10.13.13.2).";
                };
                wireguardClient = mkOption {
                    type = types.str;
                    default = "vps";
                    description = ''
                        homelab.wireguard.clients key for the VPS tunnel
                        (used to order startup after wireguard-wg-<name>.service).
                    '';
                };
            };

            xray = {
                subscriptions = {
                    alpha = mkOption {
                        type = types.bool;
                        default = true;
                        description = "Fetch and convert alpha Xray subscription outbound.";
                    };
                    beta = mkOption {
                        type = types.bool;
                        default = true;
                        description = "Fetch and convert beta Xray subscription outbound.";
                    };
                };
            };

            urltest = {
                url = mkOption {
                    type = types.str;
                    default = "http://cp.cloudflare.com/generate_204";
                    description = "Health check URL for urltest outbounds.";
                };
                interval = mkOption {
                    type = types.str;
                    default = "20s";
                    description = "Health check interval for urltest outbounds.";
                };
            };
        };

        proxychains = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable proxychains configuration.";
            };
            port = mkOption {
                type = types.int;
                default = 10808;
                description = "SOCKS5 port for proxychains.";
            };
        };

        systemProxy = {
            enable = mkEnableOption "System-wide proxy settings";
            noProxy = mkOption {
                type = types.str;
                default = "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,localhost,internal.domain";
                description = "Comma-separated list of hosts/networks to bypass proxy.";
            };
        };

        updateInterval = mkOption {
            type = types.str;
            default = "daily";
            description = "How often to refresh subscriptions (systemd calendar format).";
        };
    };

    config = mkIf cfg.enable {
        assertions = [{
            assertion = !config.desktop.xray.enable;
            message = "desktop.singbox and desktop.xray cannot both be enabled (they use the same listen port).";
        }];

        sops.secrets = mkMerge [
            {
                "smart_routing/direct-domains" = {
                    sopsFile = ../../secrets/shared/selfhost.yaml;
                    restartUnits = [ "sing-box-update-config.service" ];
                };
            }
            (mkIf cfg.outbounds.xray.subscriptions.alpha {
                "xray/subscription-alpha" = {
                    sopsFile = ../../secrets/shared/selfhost.yaml;
                    restartUnits = [ "sing-box-update-config.service" ];
                };
            })
            (mkIf cfg.outbounds.xray.subscriptions.beta {
                "xray/subscription-beta" = {
                    sopsFile = ../../secrets/shared/selfhost.yaml;
                    restartUnits = [ "sing-box-update-config.service" ];
                };
            })
        ];

        environment.systemPackages = with pkgs; [ jq sing-box ];

        systemd.services.sing-box = {
            description = "sing-box proxy";
            documentation = [ "https://sing-box.sagernet.org" ];
            after = mkAfter (
                [ "sing-box-update-config.service" "network-online.target" ]
                ++ optional cfg.outbounds.wg.enable "wireguard-wg-${cfg.outbounds.wg.wireguardClient}.service"
            );
            wants = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
                Type = "simple";
                User = "root";
                StateDirectory = "sing-box";
                WorkingDirectory = "/var/lib/sing-box";
                ExecStart = "${pkgs.sing-box}/bin/sing-box -D /var/lib/sing-box -c /etc/sing-box/config.json run";
                Restart = "on-failure";
                RestartSec = "5s";
            };
        };

        systemd.services.sing-box-update-config = {
            description = "Build sing-box config from subscriptions and routing rules";
            restartIfChanged = false;
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];
            path = with pkgs; [ jq curl coreutils sing-box ];
            script = ''
                set -uo pipefail
                mkdir -p /etc/sing-box /var/lib/sing-box/rule-sets

                RULESET_DIR=/var/lib/sing-box/rule-sets
                if ! ${pkgs.curl}/bin/curl -fsSL --connect-timeout 10 --max-time 60 \
                    -o "$RULESET_DIR/geosite-category-ru.srs" \
                    "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ru.srs"; then
                    echo "WARNING: sing-box-update-config: could not download geosite-category-ru.srs"
                fi
                if ! ${pkgs.curl}/bin/curl -fsSL --connect-timeout 10 --max-time 60 \
                    -o "$RULESET_DIR/geoip-ru.srs" \
                    "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-ru.srs"; then
                    echo "WARNING: sing-box-update-config: could not download geoip-ru.srs"
                fi

                SUB_OUTBOUNDS='[]'
                SUB_TAGS='[]'

                ${optionalString cfg.outbounds.xray.subscriptions.beta ''
                echo "Fetching subscription-beta"
                if ${pkgs.curl}/bin/curl --connect-timeout 10 --max-time 15 -fLo /tmp/singbox-sub-beta.json \
                    "$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."xray/subscription-beta".path})"; then
                    ${convertSubscription "sub-beta" "/tmp/singbox-sub-beta.json"}
                else
                    echo "WARNING: sing-box-update-config: curl failed for subscription-beta"
                fi
                ''}

                ${optionalString cfg.outbounds.xray.subscriptions.alpha ''
                echo "Fetching subscription-alpha"
                if ${pkgs.curl}/bin/curl --connect-timeout 10 --max-time 15 -fLo /tmp/singbox-sub-alpha.json \
                    "$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."xray/subscription-alpha".path})"; then
                    ${convertSubscription "sub-alpha" "/tmp/singbox-sub-alpha.json"}
                else
                    echo "WARNING: sing-box-update-config: curl failed for subscription-alpha"
                fi
                ''}

                if [ "$SUB_TAGS" = '[]' ] && [ "${if cfg.outbounds.wg.enable then "0" else "1"}" = "1" ]; then
                    if [ -f /etc/sing-box/config.json ]; then
                        echo "sing-box-update-config: subscriptions unavailable; keeping existing config"
                        exit 0
                    fi
                    echo "WARNING: sing-box-update-config: no subscriptions and no WireGuard fallback"
                    exit 0
                fi

                CUSTOM_DOMAINS=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."smart_routing/direct-domains".path} \
                    | ${pkgs.gnugrep}/bin/grep -v '^#' | ${pkgs.gnugrep}/bin/grep -v '^$' \
                    | ${pkgs.jq}/bin/jq -R . | ${pkgs.jq}/bin/jq -s .) || CUSTOM_DOMAINS='[]'

                if !                 echo "$SUB_OUTBOUNDS" | ${pkgs.jq}/bin/jq -f ${buildScript} \
                    --arg listen_port "${toString cfg.listenPort}" \
                    --arg bind_interface "${if cfg.outbounds.wg.enable then cfg.outbounds.wg.bindInterface else ""}" \
                    --arg bind_address "${if cfg.outbounds.wg.enable then cfg.outbounds.wg.bindAddress else ""}" \
                    --arg urltest_url "${cfg.outbounds.urltest.url}" \
                    --arg urltest_interval "${cfg.outbounds.urltest.interval}" \
                    --argjson custom_domains "$CUSTOM_DOMAINS" \
                    --argjson subscription_tags "$SUB_TAGS" \
                    > /etc/sing-box/config.json; then
                    echo "WARNING: sing-box-update-config: failed to build config"
                    exit 0
                fi

                if ! ${pkgs.sing-box}/bin/sing-box check -c /etc/sing-box/config.json; then
                    if [ -f /etc/sing-box/config.json.prev ]; then
                        echo "WARNING: sing-box-update-config: new config invalid; restoring previous"
                        ${pkgs.coreutils}/bin/cp /etc/sing-box/config.json.prev /etc/sing-box/config.json
                    else
                        echo "WARNING: sing-box-update-config: new config invalid and no previous config to restore"
                    fi
                    exit 0
                fi

                OLD_HASH=""
                if [ -f /etc/sing-box/config.json.prev ]; then
                    OLD_HASH=$(${pkgs.coreutils}/bin/sha256sum /etc/sing-box/config.json.prev | ${pkgs.coreutils}/bin/cut -d' ' -f1)
                fi
                NEW_HASH=$(${pkgs.coreutils}/bin/sha256sum /etc/sing-box/config.json | ${pkgs.coreutils}/bin/cut -d' ' -f1)

                if [ "$OLD_HASH" = "$NEW_HASH" ]; then
                    echo "Config unchanged, skipping sing-box restart"
                else
                    echo "Config changed, restarting sing-box"
                    ${pkgs.coreutils}/bin/cp /etc/sing-box/config.json /etc/sing-box/config.json.prev
                    ${pkgs.systemd}/bin/systemctl try-restart sing-box.service || \
                        echo "WARNING: sing-box-update-config: could not restart sing-box.service"
                fi

                exit 0
            '';
            serviceConfig.Type = "oneshot";
        };

        systemd.timers.sing-box-update-config = {
            description = "Refresh sing-box subscription outbounds";
            wantedBy = [ "timers.target" ];
            timerConfig = {
                OnCalendar = cfg.updateInterval;
                OnBootSec = "2min";
                Persistent = true;
                Unit = "sing-box-update-config.service";
            };
        };

        networking.proxy = mkIf cfg.systemProxy.enable {
            default = "socks5://127.0.0.1:${toString cfg.proxychains.port}";
            noProxy = cfg.systemProxy.noProxy;
        };

        systemd.services.nix-daemon.environment = mkIf cfg.systemProxy.enable {
            http_proxy = "socks5://127.0.0.1:${toString cfg.proxychains.port}";
            https_proxy = "socks5://127.0.0.1:${toString cfg.proxychains.port}";
            no_proxy = cfg.systemProxy.noProxy;
        };

        programs.proxychains = mkIf cfg.proxychains.enable {
            enable = true;
            quietMode = true;
            proxies = {
                singbox = {
                    enable = true;
                    type = "socks5";
                    host = "127.0.0.1";
                    port = cfg.proxychains.port;
                };
            };
        };
    };
}
