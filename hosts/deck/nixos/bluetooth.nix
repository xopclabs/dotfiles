{ config, pkgs, inputs, ... }:

{
    hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
        package = pkgs.bluez5-experimental;
        settings.General = {
            Experimental = true;
            MultiProfile = "multiple";
            Enable = "Source,Sink,Media,Socket";
            AutoEnable = true;
        };
        settings.Policy = {
            ReconnectAttempts = 7;
            ReconnectIntervals = "1,2,4,8,16,32,64";
        };
        input = {
            General.UserspaceHID = true;
        };
    };
    services.blueman.enable = true;

    # Fix controller pairing issues
    boot.extraModprobeConfig = '' options bluetooth disable_ertm=1 '';

    services.udev.extraRules = ''
        # Enable wake-up with USB
        ACTION=="add", SUBSYSTEM=="usb", DRIVER=="usb", ATTR{power/wakeup}="enabled" 
        # Enable wake-up with bluetooth
        ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="2b89", ATTRS{idProduct}=="8761"  ATTR{power/wakeup}="enabled"

        # Disable internal bluetooth
        SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0a2b", ATTR{authorized}="0"
    '';
}
