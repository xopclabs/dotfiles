{ pkgs, config, lib, ... }:

let
    cfg = config.modules.desktop.wm.hyprland;
    hardwareCfg = config.metadata.hardware;
    hypr-windowrule = pkgs.writeShellScriptBin "hypr-windowrule" ''${builtins.readFile ./hypr-windowrule}'';
    toggle-keyboard = pkgs.writeShellScriptBin "toggle-keyboard" ''${builtins.readFile ./toggle-keyboard}'';
    monitor-dpms = pkgs.writeShellScriptBin "monitor-dpms" ''
        ${builtins.replaceStrings 
            ["@INTERNAL_MONITOR@" "@EXTERNAL_MONITOR@"] 
            [hardwareCfg.monitors.internal.name hardwareCfg.monitors.external.name] 
            (builtins.readFile ./monitor-dpms)
        }
    '';
in {
    config = lib.mkIf cfg.enable {
        home.packages = [
            hypr-windowrule
            toggle-keyboard
            monitor-dpms
            pkgs.socat
        ];
    };
}