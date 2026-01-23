{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.desktop.virtual_webcam;
in
{
    options.desktop.virtual_webcam = {
        enable = mkEnableOption "Virtual Webcam";
    };

    config = mkIf cfg.enable {
        boot = {
            kernelModules = [ "v4l2loopback" ];
            extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
            extraModprobeConfig = ''
                options v4l2loopback exclusive_caps=1 card_label="Virtual Webcam"
            '';
        };
    };
}
