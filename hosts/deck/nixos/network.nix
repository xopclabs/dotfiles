{ config, pkgs, inputs, ... }:

{
    # Do not set networking.wireless.enable here. NetworkManager's module now sets it for its wpa_supplicant backend; an explicit false conflicts.
    networking = {
        networkmanager = {
            enable = true;
        };
    };
    sops.secrets."networkmanager/home" = {
        path = "/etc/NetworkManager/system-connections/home.nmconnection";
        restartUnits = [ "NetworkManager.service" "NetworkManager-dispatcher.service" ];
    };
    sops.secrets."networkmanager/rented" = {
        path = "/etc/NetworkManager/system-connections/rented.nmconnection";
        restartUnits = [ "NetworkManager.service" "NetworkManager-dispatcher.service" ];
    };
    sops.secrets."networkmanager/rented2.4g" = {
        path = "/etc/NetworkManager/system-connections/rented2.4g.nmconnection";
        restartUnits = [ "NetworkManager.service" "NetworkManager-dispatcher.service" ];
    };
    sops.secrets."networkmanager/hotspot" = {
        path = "/etc/NetworkManager/system-connections/hotspot.nmconnection";
        restartUnits = [ "NetworkManager.service" "NetworkManager-dispatcher.service" ];
    };
}
