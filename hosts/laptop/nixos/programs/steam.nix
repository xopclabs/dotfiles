{ config, pkgs, inputs, ... }:

{
    programs.steam = {
        enable = true;
        protontricks.enable = true;
    };
    hardware.xone.enable = true;
}