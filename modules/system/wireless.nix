{ config, pkgs, inputs, ... }:

{
    # Wifi
    networking = {
        networkmanager.enable = true;
        wireless.iwd.enable = true;
    };
    sops.secrets."networkmanager.conf".path = "/etc/NetworkManager/conf.d/NetworkManager.conf";

    # Bluetooth
    environment.systemPackages = with pkgs; [
        gnome.gnome-bluetooth
    ];
    hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
        settings.General.Experimental = true;
    };
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