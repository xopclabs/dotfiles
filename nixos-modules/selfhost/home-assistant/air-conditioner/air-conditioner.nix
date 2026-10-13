{ config, lib, pkgs, ... }:

let
    cfg = config.homelab.home-assistant.ac;
    python = pkgs.python3.withPackages (ps: [ ps.paho-mqtt ]);
    source = pkgs.runCommand "bodner-ac-controller" { } ''
        mkdir -p "$out"
        cp ${./coolix.py} "$out/coolix.py"
        cp ${./ac_controller.py} "$out/ac_controller.py"
    '';
    dashboard = (pkgs.formats.yaml { }).generate "air-conditioner-dashboard.yaml"
        (import ./dashboard.nix);
in
{
    options.homelab.home-assistant.ac = {
        enable = lib.mkEnableOption "Bodner COOLIX AC controls and dashboard" // { default = true; };
        blaster = lib.mkOption {
            type = lib.types.strMatching "0x[0-9a-f]{16}";
            default = "0xa4c138728237b01c";
            description = "Paired ZG-IR01 IEEE address.";
        };
    };

    config = lib.mkIf (config.homelab.home-assistant.enable && cfg.enable) {
        systemd.services.bodner-ac = {
            description = "Bodner AC MQTT controller (estimated IR state)";
            wantedBy = [ "multi-user.target" ];
            after = [ "mosquitto.service" "zigbee2mqtt.service" ];
            wants = [ "mosquitto.service" "zigbee2mqtt.service" ];
            serviceConfig = {
                DynamicUser = true;
                StateDirectory = "bodner-ac";
                UMask = "0077";
                LoadCredential = [ "mqtt-password:${config.sops.secrets."smart-home/mqtt-ha".path}" ];
                ExecStart = "${python}/bin/python ${source}/ac_controller.py --device ${cfg.blaster} --password-file %d/mqtt-password --state-file /var/lib/bodner-ac/state.json";
                Restart = "on-failure";
                RestartSec = 5;
                NoNewPrivileges = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                PrivateTmp = true;
                RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
            };
        };
        sops.secrets."smart-home/mqtt-ha".restartUnits = [ "bodner-ac.service" ];
        services.home-assistant.config.lovelace = {
            mode = "storage";
            dashboards.air-conditioner = {
                mode = "yaml";
                title = "Air Conditioner";
                icon = "mdi:air-conditioner";
                show_in_sidebar = true;
                filename = "air-conditioner.yaml";
            };
        };
        systemd.services.home-assistant.preStart = lib.mkAfter ''
            ln -sf ${dashboard} air-conditioner.yaml
        '';
    };
}
