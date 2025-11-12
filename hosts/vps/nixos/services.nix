{ config, lib, inputs, ... }:

{
    imports = [ 
        ../../../services/default.nix
    ];
    
    config.homelab = {
        # Essentials
        traefik.enable = true;
        pihole_unbound.enable = true;

        # VPN
        wireguard = {
            enable = false;
            listenPort = 51820;
            serverIP = "10.250.250.1/24";
            subnet = "10.250.250.0/24";
            externalInterface = "ens18";
            peers = {
            };
        };

        # Geolocation
        traccar.enable = false;

    };
}
