{ config, pkgs, inputs, ... }:

{
    # Wifi
    networking = {
        networkmanager = {
            enable = true;
            #settings = {
            #    ipv4.method = "auto";
            #    ipv6.method = "disabled";
            #};
            dns = "systemd-resolved";
        };
        wireless.iwd.enable = true;
        # enableIPv6 = false;
    };
    services.resolved.enable = true;
    # Disable ipv6
    # boot.kernelParams = ["ipv6.disable=1"];
    sops.secrets."networkmanager/networkmanager.conf" = {
        path = "/etc/NetworkManager/conf.d/NetworkManager.conf";
        restartUnits = [ "NetworkManager.service" "NetworkManager-dispatcher.service" ];
    };
    sops.secrets."networkmanager/home" = {
        path = "/etc/NetworkManager/system-connections/home.nmconnection";
        restartUnits = [ "NetworkManager.service" "NetworkManager-dispatcher.service" ];
    };
    sops.secrets."networkmanager/hotspot" = {
        path = "/etc/NetworkManager/system-connections/hotspot.nmconnection";
        restartUnits = [ "NetworkManager.service" "NetworkManager-dispatcher.service" ];
    };

    # Make Ollama accessible as if it was on localhost
    sops.secrets."caddy/config" = {
        path = "/etc/caddy/caddy_config";
        owner = config.users.users.caddy.name;
        restartUnits = [ "caddy.service" ];
    };
    sops.secrets."caddy/env" = {
        owner = config.users.users.caddy.name;
        restartUnits = [ "caddy.service" ];
    };
    services.caddy = {
        enable = true;
        configFile = config.sops.secrets."caddy/config".path;
        environmentFile = config.sops.secrets."caddy/env".path;
    };

}
