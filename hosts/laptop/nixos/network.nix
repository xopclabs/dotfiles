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
            dns = "dnsmasq";
        };
        wireless.iwd.enable = true;
        # enableIPv6 = false;
    };
    # Disable ipv6
    # boot.kernelParams = ["ipv6.disable=1"];
    sops.secrets."networkmanager/home" = {
        path = "/etc/NetworkManager/system-connections/home.nmconnection";
        restartUnits = [ "NetworkManager.service" "NetworkManager-dispatcher.service" ];
    };
    sops.secrets."networkmanager/hotspot" = {
        path = "/etc/NetworkManager/system-connections/hotspot.nmconnection";
        restartUnits = [ "NetworkManager.service" "NetworkManager-dispatcher.service" ];
    };
}
