{ config, pkgs, lib, ... }:

let
    cfg = config.modules.desktop.wm.kanshi;

    monitors = config.metadata.hardware.monitors;
    internalMonitors = lib.filter (mon: mon.internal) (lib.attrValues monitors);
    externalMonitors = lib.filterAttrs (_: mon: !mon.internal) monitors;
    internalMonitor = if internalMonitors == [] then null else builtins.head internalMonitors;

    monitorsConfigured = internalMonitor != null && externalMonitors != {};
    positionOrDefault = mon: default: if mon.position != null then mon.position else default;

    generateWorkspaceMoves = monitorName: [
        "${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 1 ${monitorName}"
        "${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 2 ${monitorName}"
        "${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 3 ${monitorName}"
        "${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor 4 ${monitorName}"
    ];

    generateMonitorDisables = monitorNames: map (name:
        "${pkgs.hyprland}/bin/hyprctl keyword monitor \"${name}, disable\""
    ) monitorNames;

    mkInternalOutput = {
        criteria = internalMonitor.name;
        status = "enable";
        mode = internalMonitor.mode;
        scale = internalMonitor.scale;
        position = positionOrDefault internalMonitor "0,0";
        transform = internalMonitor.transform;
    };

    mkProfilesForExternal = key: ext: [
        {
            profile = {
                name = "hdmi-${key}";
                outputs = [
                    {
                        criteria = ext.name;
                        status = "enable";
                        mode = ext.mode;
                        position = positionOrDefault ext "0,0";
                        scale = ext.scale;
                    }
                    mkInternalOutput
                ];
                exec = builtins.concatStringsSep ", " ([
                    "${pkgs.awww}/bin/awww img ~/.config/wallpaper/nord.png"
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
                        position = positionOrDefault ext "0,0";
                        scale = ext.scale;
                    }
                    mkInternalOutput
                ];
                exec = builtins.concatStringsSep ", " ([
                    "${pkgs.awww}/bin/awww img ~/.config/wallpaper/nord.png"
                ] ++ generateWorkspaceMoves "DP-1");
            };
        }
    ];

    onTheGoProfile = {
        profile = {
            name = "on-the-go";
            outputs = [
                (mkInternalOutput // { position = "0,0"; })
            ];
            exec = builtins.concatStringsSep ", " ([
                "${pkgs.awww}/bin/awww img ~/.config/wallpaper/nord.png"
            ] ++ generateMonitorDisables ["HDMI-A-2" "DP-1"]);
        };
    };

    kanshiProfiles = if monitorsConfigured then
        lib.flatten (lib.mapAttrsToList mkProfilesForExternal externalMonitors) ++ [ onTheGoProfile ]
    else [];
in {
    options.modules.desktop.wm.kanshi = {
        enable = lib.mkEnableOption "kanshi monitor configuration";
    };

    config = lib.mkIf cfg.enable {
        home.packages = [ pkgs.kanshi ];

        services.kanshi = {
            enable = true;
            settings = kanshiProfiles;
        };
    };
}
