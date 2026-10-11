{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.modules.other.phoneControl.notifications;
    receiver = pkgs.writeShellApplication {
        name = "phone-notification-receiver";
        runtimeInputs = [ (pkgs.python3.withPackages (p: [ p.dbus-next ])) pkgs.openssl ];
        text = ''
            exec python3 ${./receiver.py} "$@"
        '';
    };
in {
    options.modules.other.phoneControl.notifications = {
        enable = mkEnableOption "paired HTTPS phone notification receiver";
        bind = mkOption {
            type = types.str;
            default = "0.0.0.0";
            description = "Receiver listen address; restrict access with the host firewall";
        };
        display = mkOption {
            type = types.str;
            default = "eDP-1";
            description = "DRM connector that must be awake before queued notifications are displayed";
        };
        port = mkOption {
            type = types.port;
            default = 9843;
            description = "HTTPS receiver port";
        };
    };

    config = mkIf (config.modules.other.phoneControl.enable && cfg.enable) {
        home.packages = [ receiver ];
        systemd.user.services.phone-notification-relay = {
            Unit = {
                Description = "Paired phone notification receiver";
                After = [ "graphical-session.target" ];
                PartOf = [ "graphical-session.target" ];
                ConditionPathExists = "%h/.local/share/phone-notification-relay/token";
            };
            Service = {
                ExecStart = "${receiver}/bin/phone-notification-receiver --bind ${escapeShellArg cfg.bind} --port ${toString cfg.port} --display ${escapeShellArg cfg.display}";
                Restart = "on-failure";
                RestartSec = 5;
                UMask = "0077";
                LimitCORE = 0;
                RuntimeDirectory = "phone-notification-relay";
                RuntimeDirectoryMode = "0700";
                NoNewPrivileges = true;
                ProtectSystem = "strict";
                ProtectHome = "read-only";
                ReadWritePaths = [ "%h/.local/share/phone-notification-relay" ];
                PrivateTmp = true;
            };
            Install.WantedBy = [ "graphical-session.target" ];
        };
    };
}
