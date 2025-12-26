{ pkgs, config, lib, ... }:

let
    cfg = config.modules.desktop.wm.hyprland;
    hardwareCfg = config.metadata.hardware;
    hypr-windowrule = pkgs.writeShellScriptBin "hypr-windowrule" ''${builtins.readFile ./hypr-windowrule}'';
    toggle-keyboard = pkgs.writeShellScriptBin "toggle-keyboard" ''${builtins.readFile ./toggle-keyboard}'';
    
    # Generate external monitor mappings for the script
    # Format: ["ext-key1"]="Monitor Name 1" ["ext-key2"]="Monitor Name 2"
    externalMonitorMappings = lib.concatStringsSep "\n    " (lib.mapAttrsToList 
        (k: v: ''["ext-${k}"]="${v.name}"'') 
        hardwareCfg.monitors.external);
    
    monitor-dpms = pkgs.writeShellScriptBin "monitor-dpms" ''
        ${builtins.replaceStrings 
            ["@INTERNAL_MONITOR@" "@EXTERNAL_MONITORS@"] 
            [hardwareCfg.monitors.internal.name externalMonitorMappings] 
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