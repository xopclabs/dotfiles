{ config, pkgs, lib, ... }:

let
    cfg = config.modules.desktop.wm.kanshi;

    # Get monitor names from configuration
    internalMonitor = config.metadata.hardware.monitors.internal or null;
    externalMonitor = config.metadata.hardware.monitors.external or null;

    # Check if monitors are configured
    monitorsConfigured = internalMonitor != null && externalMonitor != null;

    # Helper function to generate workspace move commands
    generateWorkspaceMoves = monitorName: [
        "${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 1 ${monitorName}"
        "${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 2 ${monitorName}"
        "${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 3 ${monitorName}"
        "${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 4 ${monitorName}"
    ];

    # Helper function to generate monitor disable commands
    generateMonitorDisables = monitorNames: map (name:
        "${pkgs.hyprland}/bin/hyprctl keyword monitor \"${name}, disable\""
    ) monitorNames;

    # Wallpaper command
    wallpaperCmd = "${pkgs.swww}/bin/swww img ~/.config/wallpaper/nord.png";

    # Define kanshi profiles using monitor names from configuration
    kanshiProfiles = if monitorsConfigured then [
        {
            profile = {
                name = "hdmi";
                outputs = [
                    {
                        criteria = "HDMI-A-2";
                        status = "enable";
                        mode = externalMonitor.mode;
                        position = externalMonitor.position;
                        scale = externalMonitor.scale;
                    }
                    {
                        criteria = internalMonitor.name;
                        status = "enable";
                        mode = internalMonitor.mode;
                        scale = internalMonitor.scale;
                        position = internalMonitor.position;
                        transform = internalMonitor.transform;
                    }
                ];
                exec = builtins.concatStringsSep ", " ([
                    "${pkgs.swww}/bin/swww img ~/.config/wallpaper/nord.png"
                ] ++ generateWorkspaceMoves "HDMI-A-2");
            };
        }
        {
            profile = {
                name = "type-c";
                outputs = [
                    {
                        criteria = "DP-1";
                        status = "enable";
                        mode = externalMonitor.mode;
                        position = externalMonitor.position;
                        scale = externalMonitor.scale;
                    }
                    {
                        criteria = internalMonitor.name;
                        status = "enable";
                        mode = internalMonitor.mode;
                        scale = internalMonitor.scale;
                        position = internalMonitor.position;
                        transform = internalMonitor.transform;
                    }
                ];
                exec = builtins.concatStringsSep ", " ([
                    "${pkgs.swww}/bin/swww img ~/.config/wallpaper/nord.png"
                ] ++ generateWorkspaceMoves "DP-1");
            };
        }
        {
            profile = {
                name = "on-the-go";
                outputs = [
                    {
                        criteria = internalMonitor.name;
                        status = "enable";
                        mode = internalMonitor.mode;
                        scale = internalMonitor.scale;
                        position = "0,0";
                        transform = internalMonitor.transform;
                    }
                ];
                exec = builtins.concatStringsSep ", " ([
                    "${pkgs.swww}/bin/swww img ~/.config/wallpaper/nord.png"
                ] ++ generateMonitorDisables ["HDMI-A-2" "DP-1"]);
            };
        }
    ] else [];
in {
    options.modules.desktop.wm.kanshi = {
        enable = lib.mkEnableOption "kanshi";
    };

    config = lib.mkIf (cfg.enable && monitorsConfigured) {
        home.packages = [ pkgs.swww ];

        # Symlink your wallpaper directory into ~/.config/hypr/wallpaper
        home.file.".config/wallpaper" = {
            recursive = true;
            source = ./wallpaper;
        };

        services.kanshi = {
            enable = true;
            settings = kanshiProfiles;
        };
    };
}
