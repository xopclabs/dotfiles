{ config, pkgs, inputs, ... }:

{
    # Wifi
    networking = {
        networkmanager = {
            enable = true;
        };
        wireless.enable = true;
    };
    sops.secrets."networkmanager/home" = {
        path = "/etc/NetworkManager/system-connections/home.nmconnection";
        restartUnits = [ "NetworkManager.service" "NetworkManager-dispatcher.service" ];
    };
    sops.secrets."networkmanager/hotspot" = {
        path = "/etc/NetworkManager/system-connections/hotspot.nmconnection";
        restartUnits = [ "NetworkManager.service" "NetworkManager-dispatcher.service" ];
    };
}
