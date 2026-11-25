{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.desktop.virtualWebcam;
in
{
    options.desktop.virtualWebcam = {
        enable = mkEnableOption "Phone Control virtual webcams";
    };

    config = mkIf cfg.enable {
        boot = {
            kernelModules = [ "v4l2loopback" ];
            extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
            extraModprobeConfig = ''
                options v4l2loopback devices=3 video_nr=40,41,42 exclusive_caps=1,1,1 card_label=Phone-Camera-Front,Phone-Camera-Rear,Phone-Camera-Internal
            '';
        };
    };
}
