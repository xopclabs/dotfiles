{ config, pkgs, inputs, ... }:

{
    # Set up networking and secure it
    networking = {
        wireless.iwd.enable = true;
    };

    hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
        settings.General.Experimental = true;
    };
}
