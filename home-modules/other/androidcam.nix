{ inputs, pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.other.androidcam;
in {
    options.modules.other.androidcam = { enable = mkEnableOption "androidcam"; };
    config = mkIf cfg.enable {
        home.packages = [ pkgs.android-tools pkgs.scrcpy pkgs.droidcam ];
        xdg.desktopEntries.androidcam = {
            name = "Android Webcam";
            exec = "${pkgs.writeScript "androidcam" ''
                ${pkgs.android-tools}/bin/adb start-server
                ${pkgs.scrcpy}/bin/scrcpy --camera-facing=front --video-source=camera --no-audio --v4l2-sink=/dev/video0 -m1024 --orientation=90
            ''}";
        };
    };
}
