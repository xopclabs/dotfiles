{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.desktop.flatpak;
in
{
    options.desktop.flatpak = {
        enable = mkEnableOption "Flatpak application support";
    };

    config = mkIf cfg.enable {
        services.flatpak.enable = true;
    };
}

