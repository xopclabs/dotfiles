{ config, pkgs, inputs, ... }:

let
    mkXrayService = name: configPath: {
        description = "xray-${name} service";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
            ExecStart = "${pkgs.xray}/bin/xray -c ${configPath}";
            Restart = "on-failure";
        };
    };
    
    mkXrayUpdateService = name: subscriptionPath: port: {
        description = "Download xray ${name} config and restart xray-${name} service";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        script = ''
            # Create data directory
            ${pkgs.coreutils}/bin/mkdir -p /etc/xray
            
            # Download config from subscription
            ${pkgs.curl}/bin/curl -fLo /tmp/xray_config_${name}_base.json $(${pkgs.coreutils}/bin/cat ${subscriptionPath})
            
            # Download latest geoip data
            ${pkgs.curl}/bin/curl -fLo /etc/xray/geoip.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
            
            # Download latest geosite data
            ${pkgs.curl}/bin/curl -fLo /etc/xray/geosite.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
            
            # Process the config to bypass Russian traffic and set port if needed
            ${pkgs.jq}/bin/jq '.routing.rules = [
              {
                "type": "field",
                "domain": ["geosite:category-ru"],
                "outboundTag": "direct"
              },
              {
                "type": "field",
                "ip": ["geoip:ru"],
                "outboundTag": "direct"
              }
            ] + (.routing.rules // [])${if port != null then " | .inbounds[0].port = ${toString port} | .inbounds[1].port = ${toString (port + 1)}" else ""}' /tmp/xray_config_${name}_base.json > /etc/xray/config-${name}.json
        '';
        serviceConfig = {
            Type = "oneshot";
            ExecStartPost = "${pkgs.systemd}/bin/systemctl restart xray-${name}.service";
        };
    };
    
    mkXrayTimer = name: {
        description = "Timer for downloading xray ${name} config every day";
        wantedBy = [ "timers.target" ];
        timerConfig = {
            OnCalendar = "daily";
            Unit = "xray${if name != "beta" then "-${name}" else ""}-update-subscription.service";
        };
    };
in
{
    sops.secrets."xray/subscription-alpha".restartUnits = [ "xray-alpha-update-subscription.service" ];
    sops.secrets."xray/subscription-beta".restartUnits = [ "xray-update-subscription.service" ];
    environment.systemPackages = with pkgs; [
        xray
        jq
    ];
    # Alpha xray server
    systemd.services.xray-alpha = mkXrayService "alpha" "/etc/xray/config-alpha.json";
    systemd.services.xray-alpha-update-subscription = mkXrayUpdateService "alpha" config.sops.secrets."xray/subscription-alpha".path 11808;
    systemd.timers.xray-alpha-update-subscription = mkXrayTimer "alpha";
    # Beta xray server
    systemd.services.xray-beta = mkXrayService "beta" "/etc/xray/config-beta.json";
    systemd.services.xray-beta-update-subscription = mkXrayUpdateService "beta" config.sops.secrets."xray/subscription-beta".path 10808;
    systemd.timers.xray-beta-update-subscription = mkXrayTimer "beta";

    # System-wide proxy configuration
    networking.proxy = {
        default = "socks5://127.0.0.1:10808";
        noProxy = "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,localhost,internal.domain";
    };
    systemd.services.nix-daemon.environment = {
        http_proxy = "socks5://127.0.0.1:10808";
        https_proxy = "socks5://127.0.0.1:10808";
        no_proxy = "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,localhost,internal.domain";
    };

    programs.proxychains = {
        enable = true;
        quietMode = true;
        proxies = {
            xray-beta = { 
                enable = true;
                type = "socks5";
                host = "127.0.0.1";
                port = 10808;
            };
            xray-alpha = {
                enable = true;
                type = "socks5";
                host = "127.0.0.1";
                port = 11808;
            };
        };
    };

    # Wireguard
    sops.secrets."vpn/home".path = "/etc/wireguard/home.conf";
    sops.secrets."vpn/home_fallback".path = "/etc/wireguard/home_fallback.conf";
    sops.secrets."vpn/beta".path = "/etc/wireguard/beta.conf";
    networking = {
        wg-quick.interfaces = {
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
        
    };

}
