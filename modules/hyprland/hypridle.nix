{ config, pkgs, lib, ... }:

with lib;
let 
    cfg = config.modules.hypridle;
    hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";
    lock = "${pkgs.hyprlock}/bin/hyprlock";
    systemctl = "${pkgs.systemd}/bin/systemctl";
in {
    options.modules.hypridle = { 
        enable = mkEnableOption "hypridle"; 
    };

    config = mkIf cfg.enable {
        services.hypridle = {
            enable = true;
            settings = {
                listener = [
                    # {
                    #    timeout = 60 * 5;
                    #    "on-timeout" = "${hyprctl} dispatch dpms off";
                    #    "on-resume" = "${hyprctl} dispatch dpms on && brightnessctl set 100%";
                    # }
                    # {
                    #    timeout = 300;
                    #    "on-timeout" = "${lock}";
                    # }
                    {
                        timeout = 60 * 15;
                        "on-timeout" = "${systemctl} suspend";
                    }
                ];
            };
        };
    };
}
