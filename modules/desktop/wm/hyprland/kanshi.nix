{ config, pkgs, ... }:

let
    monitor_internal = "eDP-1";
    monitor_external1 = "HDMI-A-2";
    monitor_external2 = "DP-1";
in {
    home.packages = [ pkgs.swww ];

    # Symlink your wallpaper directory into ~/.config/hypr/wallpaper
    home.file.".config/hypr/wallpaper" = {
        recursive = true;
        source = ./wallpaper;
    };

    services.kanshi = {
        enable = true;
        settings = [
            {
                profile = {
                    name = "desktop-hdmi";
                    outputs = [
                        {
                            criteria = monitor_external1;
                            status = "enable";
                            mode = "1920x1080@74.97";
                            position = "0,0";
                            scale = 1.0;
                        }
                        {
                            criteria = monitor_internal;
                            status = "enable";
                            mode = "1920x1080@60";
                            scale = 1.0;
                            position = "1920,0";
                        }
                    ];
                    exec = builtins.concatStringsSep ", " [
                        "${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 1 ${monitor_external1}"
                        "${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 2 ${monitor_external1}"
                        "${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 3 ${monitor_external1}"
                        "${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 4 ${monitor_external1}"
                        "${pkgs.swww}/bin/swww img ~/.config/hypr/wallpaper/nord.png"
                    ];
                };
            }
            {
                profile = {
                    name = "desktop-type-c";
                    outputs = [
                        {
                            criteria = monitor_external2;
                            status = "enable";
                            mode = "1920x1080@74.97";
                            position = "0,0";
                            scale = 1.0;
                        }
                        {
                            criteria = monitor_internal;
                            status = "enable";
                            mode = "1920x1080@60";
                            scale = 1.0;
                            position = "1920,0";
                        }
                    ];
                    exec = builtins.concatStringsSep ", " [
                        "${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 1 ${monitor_external2}"
                        "${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 2 ${monitor_external2}"
                        "${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 3 ${monitor_external2}"
                        "${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 4 ${monitor_external2}"
                        "${pkgs.swww}/bin/swww img ~/.config/hypr/wallpaper/nord.png"
                    ];
                };
            }
            {
                profile = {
                    name = "on-the-go";
                    outputs = [
                        {
                            criteria = monitor_internal;
                            status = "enable";
                            mode = "1920x1080@60";
                            scale = 1.0;
                        }
                    ];
                    exec = builtins.concatStringsSep ", " [
                        "${pkgs.hyprland}/bin/hyprctl keyword monitor \"${monitor_external1}, disable\""
                        "${pkgs.hyprland}/bin/hyprctl keyword monitor \"${monitor_external2}, disable\""
                        "${pkgs.swww}/bin/swww img ~/.config/hypr/wallpaper/nord.png"
                    ];
                };
            }
        ];
    };
}
