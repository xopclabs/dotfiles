{ config, pkgs, inputs, ... }:

{
    imports = [
        ../../../nixos-modules/desktop/default.nix
    ];
    
    config.desktop = {
        xray = {
            enable = true;
            proxychains = {
                enable = true;
                port = 10808;
            };
        };

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
                beta = {
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
                desktopSession = "hyprland-uwsm";
                deckyLoader = {
                    enable = false;
                    user = "xopc";
                };
            };
            extraPackages = true;
            hardware = {
                xoneSupport = true;
                joyconSupport = true;
                trackpadDesktop = true;
            };
        };

        lutris.enable = true;
        flatpak.enable = true;
        localsend.enable = true;
        droidcam.enable = true;
        p81.enable = true;
        
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
