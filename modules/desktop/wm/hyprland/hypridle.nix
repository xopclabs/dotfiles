{ config, pkgs, lib, ... }:

with lib;
let 
    cfg = config.modules.desktop.wm.hypridle;
in {
    options.modules.desktop.wm.hypridle = { 
        enable = mkEnableOption "hypridle";
        
        dpmsInternal = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable display power management for internal monitor";
            };
            timeout = mkOption {
                type = types.int;
                default = 300;
                description = "Seconds before turning off internal monitor";
            };
        };

        dpmsExternal = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable display power management for external monitor";
            };
            timeout = mkOption {
                type = types.int;
                default = 300;
                description = "Seconds before turning off external monitor";
            };
        };
        
        lock = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable screen locking";
            };
            timeout = mkOption {
                type = types.int;
                default = 300;
                description = "Seconds before locking screen";
            };
        };
        
        suspend = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable suspend-then-hibernate";
            };
            timeout = mkOption {
                type = types.int;
                default = 3600;
                description = "Seconds before suspend-then-hibernate";
            };
        };
    };

    config = mkIf cfg.enable {
        services.hypridle = {
            enable = true;
            settings = {
                listener = concatLists [
                    (if cfg.dpmsInternal.enable then [{
                        timeout = cfg.dpmsInternal.timeout;
                        "on-timeout" = "monitor-dpms internal off";
                        "on-resume" = "monitor-dpms internal on";
                    }] else [])
                    (if cfg.dpmsExternal.enable then [{
                        timeout = cfg.dpmsExternal.timeout;
                        "on-timeout" = "monitor-dpms external off";
                        "on-resume" = "monitor-dpms external on";
                    }] else [])
                    (if cfg.lock.enable then [{
                        timeout = cfg.lock.timeout;
                        "on-timeout" = "hyprlock";
                    }] else [])
                    (if cfg.suspend.enable then [{
                        timeout = cfg.suspend.timeout;
                        "on-timeout" = "systemctl suspend-then-hibernate";
                    }] else [])
                ];
            };
        };
    };
}
