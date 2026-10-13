{ config, lib, pkgs, ... }:

let
    cfg = config.homelab.home-assistant;
in
{
    config = lib.mkIf cfg.enable {
        services.zigbee2mqtt = {
            enable = true;
            settings = {
                serial = {
                    port = cfg.coordinator;
                    adapter = "ember";
                };
                mqtt = {
                    server = "mqtt://127.0.0.1:1883";
                    user = "zigbee2mqtt";
                };
                homeassistant.enabled = true;
                permit_join = false;
                frontend = {
                    enabled = true;
                    host = "127.0.0.1";
                    port = 8080;
                };
                advanced = {
                    network_key = "GENERATE";
                    pan_id = "GENERATE";
                    ext_pan_id = "GENERATE";
                };
            };
        };

        systemd.services.zigbee2mqtt = {
            after = [ "mosquitto.service" ];
            wants = [ "mosquitto.service" ];
            serviceConfig = {
                LoadCredential = [ "mqtt-password:${config.sops.secrets."smart-home/mqtt-zigbee2mqtt".path}" ];
                ExecStart = lib.mkForce (pkgs.writeShellScript "zigbee2mqtt-start" ''
                    export ZIGBEE2MQTT_CONFIG_MQTT_PASSWORD="$(< "$CREDENTIALS_DIRECTORY/mqtt-password")"
                    exec ${config.services.zigbee2mqtt.package}/bin/zigbee2mqtt
                '');
            };
            # Upstream recopies configuration.yaml on every start. Preserve the
            # generated network identity and subsequent UI settings instead.
            serviceConfig.ExecStartPre = lib.mkForce (pkgs.writeShellScript "zigbee2mqtt-config" ''
                if [ ! -e configuration.yaml ]; then
                    cp --no-preserve=mode ${ (pkgs.formats.yaml { }).generate "zigbee2mqtt.yaml" config.services.zigbee2mqtt.settings } configuration.yaml
                fi
            '');
        };
    };
}
