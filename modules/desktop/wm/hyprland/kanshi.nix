{ config, pkgs, ... }:

let
    laptop_internal = "BOE 0x06B7";
    deck_internal = "Valve Corporation ANX7530 U 0x00000001";
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
                    name = "laptop-hdmi";
                    outputs = [
                        {
                            criteria = monitor_external1;
                            status = "enable";
                            mode = "1920x1080@74.97";
                            position = "0,0";
                            scale = 1.0;
                        }
                        {
                            criteria = laptop_internal;
                            status = "enable";
                            mode = "1920x1080@60";
                            scale = 1.0;
                            position = "0,1080";
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
                    name = "laptop-type-c";
                    outputs = [
                        {
                            criteria = monitor_external2;
                            status = "enable";
                            mode = "1920x1080@74.97";
                            position = "0,0";
                            scale = 1.0;
                        }
                        {
                            criteria = laptop_internal;
                            status = "enable";
                            mode = "1920x1080@60";
                            scale = 1.0;
                            position = "0,1080";
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
                    name = "deck-type-c";
                    outputs = [
                        {
                            criteria = monitor_external2;
                            status = "enable";
                            mode = "1920x1080@74.97";
                            position = "0,0";
                            scale = 1.0;
                        }
                        {
                            criteria = deck_internal;
                            status = "enable";
                            mode = "800x1280@90";
                            scale = 1.0;
                            position = "0,1080";
			    transform = "270";
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
                    name = "on-the-go-laptop";
                    outputs = [
                        {
                            criteria = laptop_internal;
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
            {
                profile = {
                    name = "on-the-go-deck";
                    outputs = [
                        {
                            criteria = deck_internal;
                            status = "enable";
                            mode = "800x1280@90";
                            scale = 1.0;
                            transform = "270";
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
