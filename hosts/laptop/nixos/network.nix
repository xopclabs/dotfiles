{ config, lib, pkgs, inputs, ... }:

{
    # Wifi
    networking = {
        networkmanager = {
            enable = true;
        };
        wireless.enable = true;
        firewall.interfaces.wlp2s0.allowedTCPPorts = [ 1883 ];
        wg-quick.interfaces.telemetry = {
            autostart = true;
            configFile = config.sops.secrets."vpn/telemetry".path;
        };
    };
    sops.secrets."vpn/telemetry" = {
        sopsFile = ../../../secrets/hosts/laptop.yaml;
        path = "/etc/wireguard/telemetry.conf";
        restartUnits = [ "wg-quick-telemetry.service" ];
    };
    systemd.services = lib.mkIf config.homelab.telemetry.edge.enable {
        telemetry-forwarder.wants = [ "wg-quick-telemetry.service" ];
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
