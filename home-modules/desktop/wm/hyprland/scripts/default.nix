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

    # Helper to convert transform string to number for hyprland
    transformToNum = t: {
        "normal" = "0"; "0" = "0";
        "90" = "1";
        "180" = "2";
        "270" = "3";
        "flipped" = "4";
        "flipped-90" = "5";
        "flipped-180" = "6";
        "flipped-270" = "7";
    }.${t} or "0";
    
    # Helper to format scale (avoid 1.000000, use 1 instead)
    formatScale = s: let
        str = toString s;
    in if lib.hasSuffix ".000000" str 
       then lib.removeSuffix ".000000" str 
       else str;
    
    internalTransform = if hardwareCfg.monitors.internal ? transform 
        then transformToNum hardwareCfg.monitors.internal.transform 
        else "0";

    internal-monitor = pkgs.writeShellScriptBin "internal-monitor" ''
        ${builtins.replaceStrings 
            ["@INTERNAL_MONITOR@" "@INTERNAL_MODE@" "@INTERNAL_SCALE@" "@INTERNAL_POSITION@" "@INTERNAL_TRANSFORM@"] 
            [
                hardwareCfg.monitors.internal.name
                hardwareCfg.monitors.internal.mode
                (formatScale hardwareCfg.monitors.internal.scale)
                hardwareCfg.monitors.internal.position
                internalTransform
            ] 
            (builtins.readFile ./internal-monitor)
        }
    '';
in {
    config = lib.mkIf cfg.enable {
        home.packages = [
            hypr-windowrule
            toggle-keyboard
            monitor-dpms
            internal-monitor
            pkgs.socat
        ];
    };
}