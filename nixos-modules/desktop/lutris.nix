{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.desktop.lutris;
in
{
    options.desktop.lutris = {
        enable = mkEnableOption "Lutris gaming platform with Wine";
    };

    config = mkIf cfg.enable {
        environment.systemPackages = with pkgs; [
            wineWow64Packages.waylandFull
            winetricks
            (lutris.override {
                extraLibraries = pkgs: [
                    pkgs.nspr
                    pkgs.xorg.libXdamage
                ];
            })
        ];
    };
}

