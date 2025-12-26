{ config, pkgs, lib, ... }:

let
    cfg = config.modules.desktop.wm.kanshi;

    # Get monitor configuration
    internalMonitor = config.metadata.hardware.monitors.internal;
    externalMonitors = config.metadata.hardware.monitors.external;

    # Check if monitors are configured
    monitorsConfigured = internalMonitor != null && externalMonitors != {};

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

    # Helper to create internal monitor output config
    mkInternalOutput = {
        criteria = internalMonitor.name;
        status = "enable";
        mode = internalMonitor.mode;
        scale = internalMonitor.scale;
        position = internalMonitor.position;
        transform = internalMonitor.transform;
    };

    # Generate HDMI + Type-C profiles for each external monitor
    mkProfilesForExternal = key: ext: [
        {
            profile = {
                name = "hdmi-${key}";
                outputs = [
                    {
                        criteria = ext.name;
                        status = "enable";
                        mode = ext.mode;
                        position = ext.position;
                        scale = ext.scale;
                    }
                    mkInternalOutput
                ];
                exec = builtins.concatStringsSep ", " ([
                    "${pkgs.swww}/bin/swww img ~/.config/wallpaper/nord.png"
                ] ++ generateWorkspaceMoves "HDMI-A-2");
            };
        }
        {
            profile = {
                name = "type-c-${key}";
                outputs = [
                    {
                        criteria = ext.name;
                        status = "enable";
                        mode = ext.mode;
                        position = ext.position;
                        scale = ext.scale;
                    }
                    mkInternalOutput
                ];
                exec = builtins.concatStringsSep ", " ([
                    "${pkgs.swww}/bin/swww img ~/.config/wallpaper/nord.png"
                ] ++ generateWorkspaceMoves "DP-1");
            };
        }
    ];

    # On-the-go profile (internal monitor only)
    onTheGoProfile = {
        profile = {
            name = "on-the-go";
            outputs = [
                (mkInternalOutput // { position = "0,0"; })
            ];
            exec = builtins.concatStringsSep ", " ([
                "${pkgs.swww}/bin/swww img ~/.config/wallpaper/nord.png"
            ] ++ generateMonitorDisables ["HDMI-A-2" "DP-1"]);
        };
    };

    # Flatten all profiles: generate for each external monitor + on-the-go
    kanshiProfiles = if monitorsConfigured then
        lib.flatten (lib.mapAttrsToList mkProfilesForExternal externalMonitors) ++ [ onTheGoProfile ]
    else [];
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
