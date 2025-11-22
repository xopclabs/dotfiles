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
                beta = {
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
    };
}
