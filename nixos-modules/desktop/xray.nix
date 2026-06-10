{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.desktop.xray;
    
    mkMergeScript = ''
        echo "Loading custom direct domains"
        CUSTOM_DOMAINS=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."smart_routing/direct-domains".path} | ${pkgs.gnugrep}/bin/grep -v '^#' | ${pkgs.gnugrep}/bin/grep -v '^$' | ${pkgs.jq}/bin/jq -R . | ${pkgs.jq}/bin/jq -s .)
        echo "Merging configs"
        ${pkgs.jq}/bin/jq -s --argjson customDomains "$CUSTOM_DOMAINS" '
          .[0] as $a
          | .[1] as $b
          | ($a.outbounds[] | select(.tag=="proxy")) as $raw1
          | ($b.outbounds[] | select(.tag=="proxy")) as $raw2
          | ($raw1 | .tag="proxy1")       as $p1
          | ($raw2 | .tag="proxy2")       as $p2
          | $a
            | .inbounds = (
                .inbounds
                | map(
                    if .port == 10808 then .port = 10808
                    elif .port == 10809 then .port = 10809
                    else . end
                  )
              )
            | .outbounds = ( [$p1, $p2] + ($a.outbounds | map(select(.tag!="proxy"))) )
            | .observatory = {
                subjectSelector: ["proxy"],
                pingConfig: {
                  destination: "http://cp.cloudflare.com/",
                  interval:    "20s",
                  timeout:     "2s",
                  sampling:    3
                }
              }
            | .routing.balancers = [
                {
                  tag:         "proxy",
                  selector:    ["proxy"],
                  strategy:    { type: "random" }
                }
              ]
            | .routing.rules = (
                (if ($customDomains | length) > 0 then
                  [{ type: "field", domain: $customDomains, network: "tcp,udp", outboundTag: "direct" }]
                else [] end)
                + [
                  { type: "field", ip: ["geoip:private"], network: "tcp,udp", outboundTag: "direct" },
                  { type: "field", ip: ["geoip:ru"], network: "tcp,udp", outboundTag: "direct" },
                  { type: "field", domain: ["geosite:category-ru"], network: "tcp,udp", outboundTag: "direct" }
                ] + [
                  { type: "field", network: "tcp,udp", balancerTag:  "proxy" }
                ]
              )
        ' /tmp/xray1.json /tmp/xray2.json > /etc/xray/config.json
    '';
in
{
    options.desktop.xray = {
        enable = mkEnableOption "Xray proxy service with subscription management";

        subscriptions = {
            alpha = mkOption {
                type = types.bool;
                default = true;
                description = "Enable alpha subscription";
            };

            beta = mkOption {
                type = types.bool;
                default = true;
                description = "Enable beta subscription";
            };
        };

        proxychains = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable proxychains configuration";
            };

            port = mkOption {
                type = types.int;
                default = 10808;
                description = "SOCKS5 port for proxychains";
            };
        };

        systemProxy = {
            enable = mkEnableOption "System-wide proxy settings";

            noProxy = mkOption {
                type = types.str;
                default = "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,localhost,internal.domain";
                description = "Comma-separated list of hosts/networks to bypass proxy";
            };
        };

        updateInterval = mkOption {
            type = types.str;
            default = "daily";
            description = "How often to update subscriptions (systemd calendar format)";
        };

        geodataUpdateInterval = mkOption {
            type = types.str;
            default = "weekly";
            description = "How often to update geo data files (systemd calendar format)";
        };
    };

    config = mkIf cfg.enable {
        # SOPS secrets configuration 
        sops.secrets = mkMerge [
            {
                "smart_routing/direct-domains" = {
                    sopsFile = ../../secrets/shared/selfhost.yaml;
                    restartUnits = [ "xray-update-subscription.service" ];
                };
            }
            (mkIf cfg.subscriptions.alpha {
                "xray/subscription-alpha" = {
                    sopsFile = ../../secrets/shared/selfhost.yaml;
                    restartUnits = [ "xray-update-subscription.service" ];
                };
            })
            (mkIf cfg.subscriptions.beta {
                "xray/subscription-beta" = {
                    sopsFile = ../../secrets/shared/selfhost.yaml;
                    restartUnits = [ "xray-update-subscription.service" ];
                };
            })
        ];

        # System packages
        environment.systemPackages = with pkgs; [ jq ];

        # Xray service
        services.xray = {
            enable = true;
            settingsFile = "/etc/xray/config.json";
        };

        # Subscription update service
        systemd.services.xray-update-subscription = {
            description = "Download, merge xray configs and restart xray";
            restartIfChanged = false;
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];
            script = ''
                mkdir -p /etc/xray

                # Check if geo data files exist, if not run the update service
                if [ ! -f /etc/xray/geoip.dat ] || [ ! -f /etc/xray/geosite.dat ]; then
                    echo "Geo data missing, updating first"
                    ${pkgs.systemd}/bin/systemctl start --no-block xray-update-geodata.service
                    for i in {1..30}; do
                        [ -f /etc/xray/geoip.dat ] && [ -f /etc/xray/geosite.dat ] && break
                        sleep 1
                    done
                fi

                FETCH_FAILED=0
                # Fetch raw JSON from each subscription (with timeout)
                ${optionalString cfg.subscriptions.beta ''
                echo "Fetching subscription-beta"
                if ! ${pkgs.curl}/bin/curl --connect-timeout 10 --max-time 15 -fLo /tmp/xray1.json "$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."xray/subscription-beta".path})"; then
                    echo "WARNING: xray-update-subscription: curl failed for subscription-beta"
                    FETCH_FAILED=1
                fi
                ''}
                ${optionalString cfg.subscriptions.alpha ''
                echo "Fetching subscription-alpha"
                if ! ${pkgs.curl}/bin/curl --connect-timeout 10 --max-time 15 -fLo /tmp/xray2.json "$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."xray/subscription-alpha".path})"; then
                    echo "WARNING: xray-update-subscription: curl failed for subscription-alpha"
                    FETCH_FAILED=1
                fi
                ''}

                if [ "$FETCH_FAILED" -ne 0 ]; then
                    if [ -f /etc/xray/config.json ]; then
                        echo "xray-update-subscription: subscription fetch failed; keeping existing /etc/xray/config.json"
                        exit 0
                    fi
                    echo "xray-update-subscription: subscription fetch failed and no existing /etc/xray/config.json"
                    exit 1
                fi

                ${mkMergeScript}

                # Only restart xray if the config actually changed
                OLD_HASH=""
                if [ -f /etc/xray/config.json.prev ]; then
                    OLD_HASH=$(${pkgs.coreutils}/bin/sha256sum /etc/xray/config.json.prev | ${pkgs.coreutils}/bin/cut -d' ' -f1)
                fi
                NEW_HASH=$(${pkgs.coreutils}/bin/sha256sum /etc/xray/config.json | ${pkgs.coreutils}/bin/cut -d' ' -f1)

                if [ "$OLD_HASH" = "$NEW_HASH" ]; then
                    echo "Config unchanged, skipping xray restart"
                else
                    echo "Config changed, restarting xray"
                    ${pkgs.coreutils}/bin/cp /etc/xray/config.json /etc/xray/config.json.prev
                    ${pkgs.systemd}/bin/systemctl restart xray.service
                fi
            '';
            serviceConfig = {
                Type = "oneshot";
            };
        };

        # Subscription update timer
        systemd.timers.xray-update-subscription = {
            description = "Update xray subscriptions";
            wantedBy = [ "timers.target" ];
            timerConfig = {
                OnCalendar = cfg.updateInterval;
                OnBootSec = "2min";
                Persistent = true;
                Unit = "xray-update-subscription.service";
            };
        };

        # Geodata update service
        systemd.services.xray-update-geodata = {
            description = "Update xray geo data files";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            script = ''
                mkdir -p /etc/xray
                ${pkgs.curl}/bin/curl --connect-timeout 10 --max-time 60 -fLo /etc/xray/geoip.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
                ${pkgs.curl}/bin/curl --connect-timeout 10 --max-time 60 -fLo /etc/xray/geosite.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
            '';
            serviceConfig = {
                Type = "oneshot";
            };
        };

        # Geodata update timer
        systemd.timers.xray-update-geodata = {
            description = "Update xray geo data";
            wantedBy = [ "timers.target" ];
            timerConfig = {
                OnCalendar = cfg.geodataUpdateInterval;
                Unit = "xray-update-geodata.service";
            };
        };

        # System-wide proxy settings (optional)
        networking.proxy = mkIf cfg.systemProxy.enable {
            default = "socks5://127.0.0.1:${toString cfg.proxychains.port}";
            noProxy = cfg.systemProxy.noProxy;
        };

        systemd.services.nix-daemon.environment = mkIf cfg.systemProxy.enable {
            http_proxy = "socks5://127.0.0.1:${toString cfg.proxychains.port}";
            https_proxy = "socks5://127.0.0.1:${toString cfg.proxychains.port}";
            no_proxy = cfg.systemProxy.noProxy;
        };

        # Proxychains configuration (optional)
        programs.proxychains = mkIf cfg.proxychains.enable {
            enable = true;
            quietMode = true;
            proxies = {
                xray = {
                    enable = true;
                    type = "socks5";
                    host = "127.0.0.1";
                    port = cfg.proxychains.port;
                };
            };
        };
    };
}


