{ config, lib, ... }:

with lib;
let
    cfg = config.homelab.telemetry;
in
{
    config = mkIf cfg.enable {
        sops.secrets = {
            "mqtt/apartment-bridge/password" = {
                sopsFile = ../../../secrets/hosts/${config.metadata.hostName}.yaml;
                owner = "root";
                group = "root";
                mode = "0400";
            };
            "mqtt/telemetry-ingester/password" = {
                sopsFile = ../../../secrets/hosts/${config.metadata.hostName}.yaml;
                owner = "telemetry";
                group = "telemetry";
                mode = "0400";
            };
        };

        services.mosquitto = {
            enable = true;
            persistence = true;
            listeners = [{
                address = "10.250.250.1";
                port = 1883;
                users = {
                    apartment-bridge = {
                        passwordFile = config.sops.secrets."mqtt/apartment-bridge/password".path;
                        acl = [ "write home/apartment/#" "write homeassistant/#" ];
                    };
                    telemetry-ingester = {
                        passwordFile = config.sops.secrets."mqtt/telemetry-ingester/password".path;
                        acl = [ "read home/apartment/#" "read homeassistant/#" ];
                    };
                };
            }];
        };
    };
}
