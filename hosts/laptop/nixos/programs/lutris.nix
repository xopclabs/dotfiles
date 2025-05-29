{ config, pkgs, inputs, ... }:

{
    environment.systemPackages = with pkgs; [
        wineWowPackages.waylandFull
        winetricks
        (lutris.override {
            extraLibraries =  pkgs: [
                nspr
                xorg.libXdamage
            ];
        })
    ];
}
