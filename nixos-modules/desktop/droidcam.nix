{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.desktop.droidcam;
in
{
    options.desktop.droidcam = {
        enable = mkEnableOption "droidcam remote webcam";
    };

    config = mkIf cfg.enable {
        programs.droidcam.enable = true;
    };
}

