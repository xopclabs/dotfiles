{ config, pkgs, ... }:
let
    lock = "${pkgs.hyprlock}/bin/hyprlock";
    systemctl = "${pkgs.systemd}/bin/systemctl";
    hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";
in 
{
    home.file.".config/hypr/hypridle.conf".text = ''
        # listener {
        #  timeout = 900                              # 15min
        #  on-timeout = ${hyprctl} dispatch dpms off                            # screen off when timeout has passed
        #  on-resume = ${hyprctl} dispatch dpms on && brightnessctl set 100%    # screen on when activity is detected after timeout has fired.
        # }

        # listener {
        #    timeout = 300                              # 5 min
        #    on-timeout = ${lock}                       # lock screen when timeout has passed
        # }

        # listener {
        #   timeout = 1800                             # 30min
        #   on-timeout = ${systemctl} suspend          # suspend pc
        # }
    '';
}
