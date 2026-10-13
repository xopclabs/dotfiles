{ config, lib, pkgs, ... }:

let
    cfg = config.homelab.home-assistant;
    owner = cfg.onboarding;
in
{
    options.homelab.home-assistant.onboarding = {
        enable = lib.mkEnableOption "one-time Home Assistant owner onboarding" // { default = true; };
        username = lib.mkOption {
            type = lib.types.str;
            default = "xopc";
            description = "Initial owner username; does not rename existing accounts.";
        };
        name = lib.mkOption {
            type = lib.types.str;
            default = owner.username;
            description = "Initial owner display name.";
        };
        language = lib.mkOption {
            type = lib.types.str;
            default = "en";
            description = "Language used for initial default areas.";
        };
        sopsFile = lib.mkOption {
            type = lib.types.path;
            default = cfg.mqttSopsFile;
            description = "Sops file containing smart-home/ha-owner-password.";
        };
    };

    config = lib.mkIf (cfg.enable && owner.enable) {
        sops.secrets."smart-home/ha-owner-password".sopsFile = owner.sopsFile;

        # HA's core_config onboarding flow creates these integrations.
        services.home-assistant.extraComponents = [
            "analytics" "google_translate" "radio_browser" "shopping_list"
        ];
        systemd.services.home-assistant-onboarding = {
            description = "One-time Home Assistant onboarding";
            wantedBy = [ "multi-user.target" ];
            requires = [ "home-assistant.service" ];
            after = [ "home-assistant.service" ];
            environment.HA_INITIAL_OWNER = builtins.toJSON {
                inherit (owner) username name language;
            };
            serviceConfig = {
                Type = "oneshot";
                ExecStart = "${pkgs.python3}/bin/python3 ${./onboarding.py}";
                LoadCredential = [
                    "owner-password:${config.sops.secrets."smart-home/ha-owner-password".path}"
                ];
                DynamicUser = true;
                NoNewPrivileges = true;
                PrivateTmp = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                RestrictAddressFamilies = [ "AF_INET" ];
                IPAddressAllow = "127.0.0.1/32";
                IPAddressDeny = "any";
                UMask = "0077";
                TimeoutStartSec = "5min";
            };
        };
    };
}
