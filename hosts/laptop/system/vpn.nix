{ config, pkgs, inputs, ... }:

{
    # Wireguard
    sops.secrets."vpn/home".path = "/etc/wireguard/home.conf";
    sops.secrets."vpn/home_fallback".path = "/etc/wireguard/home_fallback.conf";
    sops.secrets."vpn/vps".path = "/etc/wireguard/vps.conf";
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
            vps = {
                configFile = config.sops.secrets."vpn/vps".path;
                autostart = false;
            };
        };
    };

    # XRay
    sops.secrets."xray/vps".path = "/etc/xray/config.json";
    sops.secrets."xray/vps".mode = "0666";
    sops.secrets."xray/vps".owner = config.users.users.xopc.name;
    sops.secrets."xray/vps".group = config.users.users.xopc.group;
    services.xray = {
        enable = true;
        settingsFile = config.sops.secrets."xray/vps".path;
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
