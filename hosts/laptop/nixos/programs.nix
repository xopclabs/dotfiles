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
                };
                home_lan = {
                    enable = true;
                    autostart = false;
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
            extraPackages = true;
            hardware = {
                xoneSupport = true;
            };
        };

        lutris.enable = true;
        flatpak.enable = true;
        localsend.enable = true;
        virtual_webcam.enable = true;

        p81 = {
            enable = true;
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
    };
}
