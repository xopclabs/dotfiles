{ config, pkgs, inputs, ... }:

{
    sops.secrets."vpn/home".path = "/etc/wireguard/home.conf";
    sops.secrets."vpn/home_fallback".path = "/etc/wireguard/home_fallback.conf";
    sops.secrets."vpn/vps".path = "/etc/wireguard/vps.conf";
    # Wifi
    networking = {
        networkmanager.enable = true;
        wireless.iwd.enable = true;
        wg-quick.interfaces = {
            home = {
                configFile = config.sops.secrets."vpn/home".path;
                autostart = false;
            };
            home_fallback = {
                configFile = config.sops.secrets."vpn/home_fallback".path;
                autostart = false;
            };
            vps = {
                configFile = config.sops.secrets."vpn/vps".path;
                autostart = false;
            };
        };
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
            Enable = "Source,Sink,Media,Socket";
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
            SUBSYSTEM=="usb", ATTRS{idVendor}=="2b89", ATTRS{idProduct}=="8761" RUN+="/bin/sh -c 'echo enabled > /sys$env{DEVPATH}/../power/wakeup;'"
        '';
        destination = "/etc/udev/rules.d/91-keyboard-mouse-wakeup.rules";
        })
    ];
    services.udev.extraRules = ''
        SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0a2b", ATTR{authorized}="0"
    '';
}
