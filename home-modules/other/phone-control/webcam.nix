{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.modules.other.phoneControl.webcam;
    devices = [ "/dev/video40" "/dev/video41" "/dev/video42" ];
    relay = pkgs.writeShellApplication {
        name = "phone-webcam";
        runtimeInputs = [ pkgs.android-tools pkgs.ffmpeg pkgs.python3 pkgs.scrcpy ];
        text = ''
            exec python3 ${./webcam.py} "$@"
        '';
    };
in {
    options.modules.other.phoneControl.webcam = {
        enable = mkEnableOption "on-demand phone webcams";
        phone = mkOption {
            type = types.strMatching "adb-[A-Za-z0-9-]+";
            description = "Paired phone's wireless ADB service name without its DNS-SD suffix";
        };
    };

    config = mkIf (config.modules.other.phoneControl.enable && cfg.enable) {
        systemd.user.services.phone-webcam = {
            Unit = {
                Description = "On-demand Phone Control webcams";
                PartOf = [ "graphical-session.target" ];
            };
            Service = {
                ExecStart = "${relay}/bin/phone-webcam ${cfg.phone} ${concatStringsSep " " devices}";
                Restart = "on-failure";
                RestartSec = 3;
                KillMode = "mixed";
                NoNewPrivileges = true;
                LimitCORE = 0;
            };
            Install.WantedBy = [ "graphical-session.target" ];
        };
    };
}
