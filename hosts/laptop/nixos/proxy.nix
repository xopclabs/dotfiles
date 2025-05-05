{ config, pkgs, inputs, ... }:

let 
    noProxy = "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,localhost,internal.domain";
in {
    # xray
    sops.secrets."xray/subscription-alpha".restartUnits = [ "xray-update-subscription.service" ];
    sops.secrets."xray/subscription-beta".restartUnits = [ "xray-update-subscription.service" ];
    environment.systemPackages = with pkgs; [
        jq
    ];
    services.xray = {
        enable = true;
        settingsFile = "/etc/xray/config.json";
    };
    systemd.services.xray-update-subscription = {
        description = "Download, merge xray configs and restart xray";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
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

            # Fetch raw JSON from each subscription
            echo "Fetching subscription-beta"
            ${pkgs.curl}/bin/curl -fLo /tmp/xray1.json $(${pkgs.coreutils}/bin/cat ${config.sops.secrets."xray/subscription-beta".path})
            echo "Fetching subscription-alpha"
            ${pkgs.curl}/bin/curl -fLo /tmp/xray2.json $(${pkgs.coreutils}/bin/cat ${config.sops.secrets."xray/subscription-alpha".path})

            echo "Merging configs"
            # Merge JSON configs into one
            ${pkgs.jq}/bin/jq -s '
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
                    subjectSelector: ["proxy1"],
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
                      selector:    ["proxy1"],
                      fallbackTag: "proxy2",
                      strategy:    { type: "random" }
                    }
                  ]
                | .routing.rules = (
                    [
                      { type: "field", ip: ["geoip:ru"], network: "tcp,udp", outboundTag: "direct" },
                      { type: "field", domain: ["geosite:category-ru"], network: "tcp,udp", outboundTag: "direct" }
                    ] + [
                      { type: "field", network: "tcp,udp", balancerTag:  "proxy" }
                    ]
                  )
            ' /tmp/xray1.json /tmp/xray2.json > /etc/xray/config.json
        '';
        serviceConfig = {
            Type = "oneshot";
            ExecStartPost = "${pkgs.systemd}/bin/systemctl restart xray.service";
        };
    };
    systemd.timers.xray-update-subscription = {
        description = "Update xray subscriptions daily";
        wantedBy = [ "timers.target" ];
        timerConfig = {
            OnCalendar = "daily";
            Unit = "xray-update-subscription.service";
        };
    };
    systemd.services.xray-update-geodata = {
        description = "Update xray geo data files";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        script = ''
            mkdir -p /etc/xray
            ${pkgs.curl}/bin/curl -fLo /etc/xray/geoip.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
            ${pkgs.curl}/bin/curl -fLo /etc/xray/geosite.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
        '';
        serviceConfig = {
            Type = "oneshot";
        };
    };
    systemd.timers.xray-update-geodata = {
        description = "Update xray geo data weekly";
        wantedBy = [ "timers.target" ];
        timerConfig = {
            OnCalendar = "weekly";
            Unit = "xray-update-geodata.service";
        };
    };

    # # System-wide proxy settings
    networking.proxy = {
        default = "socks5://127.0.0.1:10808";
        noProxy = noProxy;
    };
    systemd.services.nix-daemon.environment = {
        http_proxy = "socks5://127.0.0.1:10808";
        https_proxy = "socks5://127.0.0.1:10808";
        no_proxy = noProxy;
    };

    # proxychains for backwards compatibility (I'm too lazy to fix all the scripts)
    programs.proxychains = {
        enable = true;
        quietMode = true;
        proxies = {
            xray = {
                enable = true;
                type = "socks5";
                host = "127.0.0.1";
                port = 10808;
            };
        };
    };

    # Wireguard
    sops.secrets."vpn/home".path = "/etc/wireguard/home.conf";
    sops.secrets."vpn/home_fallback".path = "/etc/wireguard/home_fallback.conf";
    sops.secrets."vpn/beta".path = "/etc/wireguard/beta.conf";
    networking.wg-quick.interfaces = {
        home = {
            configFile = config.sops.secrets."vpn/home".path;
            autostart = false;
        };
        home_fallback = {
            configFile = config.sops.secrets."vpn/home_fallback".path;
            autostart = false;
        };
        beta = {
            configFile = config.sops.secrets."vpn/beta".path;
            autostart = false;
        };
    };
}
