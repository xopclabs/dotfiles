{ config, lib, ... }:

let
    cfg = config.homelab.telemetry.server;
in
{
    config = lib.mkIf cfg.enable {
        services.mosquitto = {
            enable = true;
            settings = {
                max_queued_messages = 100000;
                max_queued_bytes = 134217728;
                queue_qos0_messages = false;
            };
        };
        sops.secrets = lib.genAttrs [
            "mqtt/homelab/apartment-bridge/password"
            "mqtt/homelab/telemetry-ingester/password"
        ] (_: {
            sopsFile = ../../../../secrets/shared/selfhost.yaml;
            restartUnits = [ "mosquitto.service" ];
        });
        homelab.mosquitto.listeners.receiver = {
            address = cfg.listenAddress;
            users = {
                apartment-bridge = {
                    passwordFile = config.sops.secrets."mqtt/homelab/apartment-bridge/password".path;
                    acl = [ "write apartment/#" "write home/apartment/#" "write homeassistant/#" "write telemetry/forward" "read telemetry/ack/#" ];
                };
                telemetry-ingester = {
                    passwordFile = config.sops.secrets."mqtt/homelab/telemetry-ingester/password".path;
                    acl = [ "read apartment/#" "read home/apartment/#" "read homeassistant/#" "read telemetry/forward" "write telemetry/ack/#" ];
                };
            };
        };
    };
}
