{ config, pkgs, inputs, ... }:

{
    sops.secrets."xray/subscription-alpha".restartUnits = [ "xray-update-subscription.service" ];
    sops.secrets."xray/subscription-beta".restartUnits = [ "xray-update-subscription.service" ];
    sops.secrets."xray/direct-domains".restartUnits = [ "xray-update-subscription.service" ];

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

            echo "Loading custom direct domains"
            # Read custom domains from sops secret and convert to JSON array
            CUSTOM_DOMAINS=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."xray/direct-domains".path} | ${pkgs.gnugrep}/bin/grep -v '^#' | ${pkgs.gnugrep}/bin/grep -v '^$' | ${pkgs.jq}/bin/jq -R . | ${pkgs.jq}/bin/jq -s .)
            
            echo "Merging configs"
            # Merge JSON configs into one
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
                    (if ($customDomains | length) > 0 then
                      [{ type: "field", domain: $customDomains, network: "tcp,udp", outboundTag: "direct" }]
                    else [] end)
                    + [
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
}

