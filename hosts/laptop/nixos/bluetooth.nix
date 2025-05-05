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

    # For wake-up with bluetooth (doesn't work)
    services.udev.packages = [
        (pkgs.writeTextFile {
        name = "bluetooth_udev";
        text = ''
            SUBSYSTEM=="usb", ATTRS{idVendor}=="2b89", ATTRS{idProduct}=="8761" RUN+="${pkgs.coreutils}/bin/echo enabled > /sys$env{DEVPATH}/../power/wakeup"
        '';
        destination = "/etc/udev/rules.d/91-keyboard-mouse-wakeup.rules";
        })
    ];

    services.udev.extraRules = ''
        # Disable internal bluetooth
        SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0a2b", ATTR{authorized}="0"
    '';
}
