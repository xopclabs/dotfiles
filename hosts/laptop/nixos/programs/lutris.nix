{ config, pkgs, inputs, ... }:

{
    environment.systemPackages = with pkgs; [
        wineWow64Packages.waylandFull
        winetricks
        (lutris.override {
            extraLibraries =  pkgs: [
                nspr
                xorg.libXdamage
            ];
        })
    ];
}
