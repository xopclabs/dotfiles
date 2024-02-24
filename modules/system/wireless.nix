{ config, pkgs, inputs, ... }:

{
    # Hosts
    #networking.hosts = {};
    #sops.secrets.hosts.path = "/etc/hosts";

    # Wifi
    networking = {
        networkmanager.enable = true;
        wireless.iwd.enable = true;
    };
    sops.secrets."networkmanager.conf".path = "/etc/NetworkManager/conf.d/NetworkManager.conf";

    # Bluetooth
    hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
        #package = pkgs.bluez5-experimental;
        settings.General = {
            Experimental = true;
            MultiProfile = "multiple";
        };
        input = {
            General.UserspaceHID = true;
        };
    };
    services.blueman.enable = true;
    # For wake-up with bluetooth
    services.udev.packages = [
        (pkgs.writeTextFile {
        name = "bluetooth_udev";
        text = ''
            SUBSYSTEM=="usb", ATTRS{idVendor}=="8087", ATTRS{idProduct}=="0a2b" RUN+="/bin/sh -c 'echo enabled > /sys$env{DEVPATH}/../power/wakeup;'"
        '';

        destination = "/etc/udev/rules.d/91-keyboard-mouse-wakeup.rules";
        })
    ];
    services.udev.extraRules = ''
    '';
}
