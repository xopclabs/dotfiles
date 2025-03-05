{ config, pkgs, ... }:

let
    monitor_internal = "eDP-1";
    monitor_external = "HDMI-A-2";
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
                    name = "desktop";
                    outputs = [
                        {
                            criteria = monitor_external;
                            status = "enable";
                            mode = "1920x1080@75";
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
                        "${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 1 ${monitor_external}"
                        "${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 2 ${monitor_external}"
                        "${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 3 ${monitor_external}"
                        "${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 4 ${monitor_external}"
                        "${pkgs.swww}/bin/swww img -o ${monitor_external} $(${pkgs.busybox}/bin/find ~/.config/hypr/wallpaper \\( -type f -o -type l \\) | ${pkgs.busybox}/bin/shuf -n 1)"
                        "${pkgs.swww}/bin/swww img -o ${monitor_internal} $(${pkgs.busybox}/bin/find ~/.config/hypr/wallpaper \\( -type f -o -type l \\) | ${pkgs.busybox}/bin/shuf -n 1)"
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
                        "${pkgs.hyprland}/bin/hyprctl keyword monitor \"${monitor_external}, disable\""
                        "${pkgs.swww}/bin/swww img -o ${monitor_internal} $(${pkgs.busybox}/bin/find ~/.config/hypr/wallpaper \\( -type f -o -type l \\) | ${pkgs.busybox}/bin/shuf -n 1)"
                    ];
                };
            }
        ];
    };
}
