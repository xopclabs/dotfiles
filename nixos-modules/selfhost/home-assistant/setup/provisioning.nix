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
    options.homelab.home-assistant.provisioning = {
        enable = lib.mkEnableOption "API reconciliation of Home Assistant configuration" // { default = true; };
        users = lib.mkOption {
            default = { };
            description = "Managed local-only non-admin Home Assistant accounts, keyed by username.";
            type = lib.types.attrsOf (lib.types.submodule {
                options = {
                    name = lib.mkOption { type = lib.types.str; };
                    passwordSecret = lib.mkOption {
                        type = lib.types.str;
                        description = "Sops key in the shared Home Assistant secrets file.";
                    };
                };
            });
        };
    };

    config = lib.mkIf (cfg.enable && cfg.provisioning.enable) {
        assertions = [ {
            assertion = cfg.onboarding.enable;
            message = "home-assistant provisioning requires onboarding owner credentials.";
        } ] ++ lib.mapAttrsToList (username: user: {
            assertion = builtins.match "[a-z0-9][a-z0-9_-]*" username != null;
            message = "Managed HA usernames must be safe systemd credential names.";
        }) cfg.provisioning.users;
        sops.secrets = {
            "smart-home/ha-owner-password".restartUnits = [ "home-assistant-provisioning.service" ];
            "smart-home/mqtt-ha".restartUnits = [ "home-assistant-provisioning.service" ];
        } // lib.mapAttrs' (username: user:
            lib.nameValuePair user.passwordSecret {
                sopsFile = cfg.onboarding.sopsFile;
                restartUnits = [ "home-assistant-provisioning.service" ];
            }) cfg.provisioning.users;

        systemd.services.home-assistant-provisioning = {
            description = "Reconcile local Home Assistant integrations";
            wantedBy = [ "multi-user.target" ];
            requires = [ "home-assistant.service" "home-assistant-onboarding.service" "mosquitto.service" ];
            after = [ "home-assistant.service" "home-assistant-onboarding.service" "mosquitto.service" ];
            environment = {
                HA_OWNER_USERNAME = cfg.onboarding.username;
                HA_MANAGED_USERS = builtins.toJSON (lib.mapAttrs (username: user: {
                    inherit (user) name;
                    credential = "user-${username}-password";
                }) cfg.provisioning.users);
            };
            serviceConfig = {
                Type = "oneshot";
                ExecStart = "${python}/bin/python3 ${scripts}/provisioning.py";
                LoadCredential = [
                    "owner-password:${config.sops.secrets."smart-home/ha-owner-password".path}"
                    "mqtt-password:${config.sops.secrets."smart-home/mqtt-ha".path}"
                ] ++ lib.mapAttrsToList (username: user:
                    "user-${username}-password:${config.sops.secrets.${user.passwordSecret}.path}")
                    cfg.provisioning.users;
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
