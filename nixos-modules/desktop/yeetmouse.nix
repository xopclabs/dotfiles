{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.desktop.yeetmouse;
in
{
    options.desktop.yeetmouse = {
        enable = mkEnableOption "Yeetmouse custom mouse acceleration";

        sensitivity = mkOption {
            type = types.float;
            default = 1.0;
            description = "Mouse sensitivity";
        };

        mode = {
            acceleration = mkOption {
                type = types.float;
                default = 1.5;
                description = "Acceleration factor";
            };

            midpoint = mkOption {
                type = types.float;
                default = 7.5;
                description = "Acceleration midpoint";
            };

            smoothness = mkOption {
                type = types.float;
                default = 0.01;
                description = "Smoothness value";
            };

            useSmoothing = mkOption {
                type = types.bool;
                default = false;
                description = "Enable smoothing";
            };
        };
    };

    config = mkIf cfg.enable {
        hardware.yeetmouse = {
            enable = true;
            sensitivity = cfg.sensitivity;
            mode.jump = {
                acceleration = cfg.mode.acceleration;
                midpoint = cfg.mode.midpoint;
                smoothness = cfg.mode.smoothness;
                useSmoothing = cfg.mode.useSmoothing;
            };
        };
    };
}

