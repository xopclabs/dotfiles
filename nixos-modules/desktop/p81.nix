{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.desktop.p81;
in
{
    options.desktop.p81 = {
        enable = mkEnableOption "Perimeter81 corporate VPN support";
    };

    config = mkIf cfg.enable {
        services.perimeter81.enable = true;
    };
}

