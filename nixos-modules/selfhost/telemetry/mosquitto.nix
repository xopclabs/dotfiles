{ config, lib, ... }:

with lib;
let
    cfg = config.homelab.telemetry;
in
{
    config = mkIf cfg.enable {
        sops.secrets = {
            "mqtt/homelab/apartment-bridge/password" = {
                sopsFile = ../../../secrets/shared/selfhost.yaml;
                owner = "root";
                group = "root";
                mode = "0400";
            };
            "mqtt/homelab/telemetry-ingester/password" = {
                sopsFile = ../../../secrets/shared/selfhost.yaml;
                owner = "telemetry";
                group = "telemetry";
                mode = "0400";
            };
        };

        services.mosquitto = {
            enable = true;
            persistence = true;
            settings = {
                autosave_interval = 60;
                max_queued_messages = 100000;
                max_queued_bytes = 134217728;
            };
            listeners = [{
                address = "10.250.250.1";
                port = 1883;
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
            }];
        };
    };
}
