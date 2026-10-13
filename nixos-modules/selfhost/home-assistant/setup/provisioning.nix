{ config, lib, pkgs, ... }:

let
    cfg = config.homelab.home-assistant;
    python = pkgs.python3.withPackages (ps: [ ps.aiohttp ]);
    scripts = pkgs.runCommand "home-assistant-provisioning" { } ''
        mkdir -p $out
        cp ${./onboarding.py} $out/onboarding.py
        cp ${./provisioning.py} $out/provisioning.py
    '';
in
{
    options.homelab.home-assistant.provisioning.enable = lib.mkEnableOption
        "API reconciliation of the local Home Assistant MQTT and proxy configuration" // { default = true; };

    config = lib.mkIf (cfg.enable && cfg.provisioning.enable) {
        assertions = [ {
            assertion = cfg.onboarding.enable;
            message = "home-assistant provisioning requires onboarding owner credentials.";
        } ];
        sops.secrets."smart-home/ha-owner-password".restartUnits = [ "home-assistant-provisioning.service" ];
        sops.secrets."smart-home/mqtt-ha".restartUnits = [ "home-assistant-provisioning.service" ];

        systemd.services.home-assistant-provisioning = {
            description = "Reconcile local Home Assistant integrations";
            wantedBy = [ "multi-user.target" ];
            requires = [ "home-assistant.service" "home-assistant-onboarding.service" "mosquitto.service" ];
            after = [ "home-assistant.service" "home-assistant-onboarding.service" "mosquitto.service" ];
            environment.HA_OWNER_USERNAME = cfg.onboarding.username;
            serviceConfig = {
                Type = "oneshot";
                ExecStart = "${python}/bin/python3 ${scripts}/provisioning.py";
                LoadCredential = [
                    "owner-password:${config.sops.secrets."smart-home/ha-owner-password".path}"
                    "mqtt-password:${config.sops.secrets."smart-home/mqtt-ha".path}"
                ];
                DynamicUser = true;
                NoNewPrivileges = true;
                PrivateTmp = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                RestrictAddressFamilies = [ "AF_INET" "AF_UNIX" ];
                IPAddressAllow = "127.0.0.1/32";
                IPAddressDeny = "any";
                UMask = "0077";
                TimeoutStartSec = "10min";
            };
        };
    };
}
