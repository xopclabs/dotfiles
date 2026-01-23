{ config, pkgs, inputs, ... }:

{
    # Wifi
    networking = {
        # Static ip
        useDHCP = false;
            interfaces.wlan0 = {
                useDHCP = false;
                ipv4.addresses = [
                    {
                        address = config.metadata.network.ipv4;
                        prefixLength = 24;
                    }
                ];
            };
        defaultGateway = config.metadata.network.defaultGateway;
        nameservers = [ "127.0.0.1" "9.9.9.9" ];

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
