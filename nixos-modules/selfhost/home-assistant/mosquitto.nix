{ config, lib, ... }:

let
    cfg = config.homelab.home-assistant;
in
{
    config = lib.mkIf cfg.enable {
        sops.secrets = {
            "smart-home/mqtt-ha".sopsFile = cfg.mqttSopsFile;
            "smart-home/mqtt-zigbee2mqtt" = {
                sopsFile = cfg.mqttSopsFile;
                owner = "zigbee2mqtt";
                restartUnits = [ "mosquitto.service" "zigbee2mqtt.service" ];
            };
        };
        sops.secrets."smart-home/mqtt-ha".restartUnits = [ "mosquitto.service" ];

        services.mosquitto = {
            enable = true;
            persistence = true;
            listeners = [ {
                address = "127.0.0.1";
                settings.allow_anonymous = false;
                users = {
                    home-assistant = {
                        passwordFile = config.sops.secrets."smart-home/mqtt-ha".path;
                        acl = [ "readwrite zigbee2mqtt/#" "readwrite homeassistant/#" ];
                    };
                    zigbee2mqtt = {
                        passwordFile = config.sops.secrets."smart-home/mqtt-zigbee2mqtt".path;
                        acl = [ "readwrite zigbee2mqtt/#" "readwrite homeassistant/#" ];
                    };
                };
            } ];
        };
    };
}
