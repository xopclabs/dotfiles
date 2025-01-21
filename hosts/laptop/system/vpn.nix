{ config, pkgs, inputs, ... }:

{
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

    # XRay
    services.xray = {
        enable = true;
        settingsFile = "/etc/xray/config.json";
    };
    # Define the systemd subscription service
    sops.secrets."xray/subscription-beta" = {
        restartUnits = [ "xray-update-subscription.service" ];
    };
    systemd.services.xray-update-subscription = {
        description = "Download xray config and restart xray service";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        script = ''
            ${pkgs.curl}/bin/curl -fLo /etc/xray/config.json $(${pkgs.coreutils}/bin/cat ${config.sops.secrets."xray/subscription-beta".path})
        '';
        serviceConfig = {
            Type = "oneshot";
            ExecStartPost = "${pkgs.systemd}/bin/systemctl restart xray.service";
        };
    };
    # Define the systemd timer
    systemd.timers.xray-update-subscription = {
        description = "Timer for downloading xray config every 12 hours";
        wantedBy = [ "timers.target" ];
        timerConfig = {
            OnCalendar = "daily";
            Unit = "xray-update-subscription.service";
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
