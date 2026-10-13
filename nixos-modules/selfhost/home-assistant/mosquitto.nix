{ config, lib, ... }:

{
    config = lib.mkIf config.homelab.home-assistant.enable {
        services.mosquitto.enable = true;
        sops.secrets."smart-home/mqtt-ha" = {
            sopsFile = ../../../secrets/shared/selfhost.yaml;
            restartUnits = [ "mosquitto.service" ];
        };
        homelab.mosquitto.listeners.local = {
            address = "127.0.0.1";
            users.home-assistant = {
                passwordFile = config.sops.secrets."smart-home/mqtt-ha".path;
                acl = [ "readwrite zigbee2mqtt/#" "readwrite homeassistant/#" ];
            };
        };
    };
}
