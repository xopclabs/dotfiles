{ config, pkgs, lib, ... }:

with lib;
let 
    cfg = config.modules.desktop.wm.hypridle;
in {
    options.modules.desktop.wm.hypridle = { 
        enable = mkEnableOption "hypridle";
        
        dpms = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable display power management";
            };
            timeout = mkOption {
                type = types.int;
                default = 300;
                description = "Seconds before turning off display";
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
                    (if cfg.dpms.enable then [{
                        timeout = cfg.dpms.timeout;
                        "on-timeout" = "hyprctl dispatch dpms off";
                        "on-resume" = "hyprctl dispatch dpms on && brightnessctl set 100%";
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
