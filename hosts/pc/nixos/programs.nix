{ config, pkgs, inputs, ... }:

{
    imports = [
        ../../../nixos-modules/desktop/default.nix
    ];
    
    config.desktop = {
        wireguard = {
            enable = true;
            peers = {
                home = {
                    enable = true;
                    autostart = false;
                    sopsFile = ../../../secrets/hosts/pc.yaml;
                };
                home_lan = {
                    enable = true;
                    autostart = true;
                    sopsFile = ../../../secrets/hosts/pc.yaml;
                };
                home_pi = {
                    enable = true;
                    autostart = false;
                };
                vps = {
                    enable = true;
                    autostart = false;
                };
            };
        };

        steam = {
            enable = true;
            jovian = {
                enable = true;
                autoStart = true;
                desktopSession = "niri";
                steamDeck.enable = false;
                deckyLoader = {
                    enable = false;
                    user = "xopc";
                };
            };
            gamescopeSession.enable = false;
            extraPackages = true;
            hardware = {
                xoneSupport = true;
                joyconSupport = true;
            };
        };

        deckControllerPassthrough = {
            enable = true;
            role = "importer";
            exporterAddress = "192.168.1.151";
        };

        lutris.enable = true;
        flatpak.enable = true;
        localsend.enable = true;
        ddcutil.enable = true;
        touchUnlock = {
            enable = true;
            allowVendorDrivers = true;
            inputSettleTimeoutSec = 3;
            extraKernelModules = [
                "usbhid"
                "hid_generic"
                "hid_multitouch"
                "evdev"
            ];
        };
        virtual_webcam.enable = false;
        p81 = {
            enable = true;
            autostart = false;
            splitDns.enable = true;
            sleepResumeRecovery = "async-reset";
            sleepResumeDelaySec = 30;
        };
        ereader_relay = {
            enable = true;
            subdomain = "books.vm.local";
        };

        vanta = {
            enable = true;
        };

        yeetmouse = {
            enable = false; 
            sensitivity = 1.0;
            mode = {
                acceleration = 1.5;
                midpoint = 7.5;
                smoothness = 0.01;
                useSmoothing = false;
            };
        };
    };
}
