{ config, pkgs, lib, ... }:

with lib;
let
    cfg = config.modules.desktop.wm.scripts;
    hardwareCfg = config.metadata.hardware;
    internal = hardwareCfg.monitors.internal;
    wmEnabled = config.modules.desktop.wm.hyprland.enable || config.modules.desktop.wm.niri.enable;

    formatScale = s: let
        str = toString s;
    in if lib.hasSuffix ".000000" str
       then lib.removeSuffix ".000000" str
       else str;

    screenshot = pkgs.writeShellScriptBin "screenshot" ''
    	grim -g "$(slurp -d)" - | wl-copy
    '';
    annotate = pkgs.writeShellScriptBin "annotate" ''
        wl-paste | swappy -f - -o - | wl-copy
    '';
    screenrecord = pkgs.writeShellScriptBin "screenrecord" ''
        # Check if wf-recorder is currently running
        if pgrep -x wf-recorder > /dev/null; then
            echo "Stopping wf-recorder..."
            pkill -SIGINT wf-recorder
        else
            echo "Starting wf-recorder..."
            wf-recorder -g "$(slurp)" -f ~/screenshots/$(date +'%Y-%m-%d_%H-%M-%S').mkv &
        fi
    '';

    scriptPath = lib.makeBinPath (
        [
            pkgs.coreutils
            pkgs.evtest
            pkgs.gnugrep
            pkgs.gnused
            pkgs.jq
            pkgs.procps
            pkgs.socat
            pkgs.systemd
            pkgs.util-linux
        ]
        ++ lib.optional config.modules.desktop.wm.hyprland.enable pkgs.hyprland
        ++ lib.optional config.modules.desktop.wm.niri.enable pkgs.niri
    );

    compositorLib = pkgs.writeText "compositor-lib.sh" (
        builtins.replaceStrings
            [
                "@INTERNAL_NAME@"
                "@INTERNAL_MODE@"
                "@INTERNAL_SCALE@"
                "@INTERNAL_POSITION@"
                "@INTERNAL_TRANSFORM@"
                "@INTERNAL_CONNECTOR@"
                "@EXTERNAL_MONITORS@"
                "@EXTERNAL_CONNECTORS@"
            ]
            [
                (if internal != null then internal.name else "")
                (if internal != null then internal.mode else "")
                (if internal != null then formatScale internal.scale else "1")
                (if internal != null then internal.position else "0x0")
                (if internal != null then (internal.transform or "normal") else "normal")
                (if internal != null && internal.connector != null then internal.connector else "")
                (lib.concatStringsSep "\n    " (lib.mapAttrsToList
                    (k: v: ''["ext-${k}"]="${v.name}"'')
                    hardwareCfg.monitors.external))
                (lib.concatStringsSep "\n    " (lib.mapAttrsToList
                    (k: v: ''["ext-${k}"]="${if v.connector != null then v.connector else ""}"'')
                    hardwareCfg.monitors.external))
            ]
            (builtins.readFile ./lib)
    );

    mkWmScript = name: pkgs.writeShellScriptBin name ''
        export PATH=${scriptPath}:$PATH
        ${builtins.replaceStrings ["@LIB@"] [(toString compositorLib)] (builtins.readFile ./${name})}
    '';

    window-rule = mkWmScript "window-rule";
    monitor-dpms = mkWmScript "monitor-dpms";
    internal-monitor = mkWmScript "internal-monitor";
    keyboard-disable = mkWmScript "keyboard-disable";
in {
    options.modules.desktop.wm.scripts = {
        enable = mkEnableOption "scripts";
    };

    config = mkMerge [
        (mkIf cfg.enable {
            home.packages = [
                screenshot pkgs.grim pkgs.slurp
                annotate pkgs.swappy
                screenrecord pkgs.wf-recorder
                pkgs.wl-clipboard
            ];
        })
        (mkIf (cfg.enable && wmEnabled) {
            home.packages = [
                window-rule
                monitor-dpms
                internal-monitor
                keyboard-disable
            ];

            systemd.user.services.window-rule = {
                Unit = {
                    Description = "Dynamic window rules for the current compositor";
                    After = [ "graphical-session.target" ];
                    PartOf = [ "graphical-session.target" ];
                    ConditionEnvironment = "WAYLAND_DISPLAY";
                };
                Service = {
                    ExecStart = "${window-rule}/bin/window-rule";
                    Restart = "always";
                    RestartSec = 1;
                };
                Install.WantedBy = [ "graphical-session.target" ];
            };
        })
        (mkIf (cfg.enable && wmEnabled && internal != null) {
            systemd.user.services.internal-monitor-watch = {
                Unit = {
                    Description = "Restore internal monitor preference and enable it when no external is connected";
                    After = [ "graphical-session.target" ];
                    PartOf = [ "graphical-session.target" ];
                    ConditionEnvironment = "WAYLAND_DISPLAY";
                };
                Service = {
                    ExecStart = "${internal-monitor}/bin/internal-monitor watch";
                    Restart = "always";
                    RestartSec = 1;
                };
                Install.WantedBy = [ "graphical-session.target" ];
            };
        })
    ];
}
