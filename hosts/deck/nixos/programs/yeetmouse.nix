{ config, pkgs, inputs, ... }:

{
    # Mouse acceleration
    hardware.yeetmouse = {
        enable = false;
        sensitivity = 1.0;
        mode.jump = {
            acceleration = 1.5;
            midpoint = 7.5;
            smoothness = 0.01;
            useSmoothing = false;
        };
    };
}

