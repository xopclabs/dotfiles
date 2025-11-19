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
