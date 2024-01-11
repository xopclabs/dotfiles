{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.flameshot;
in {
    options.modules.flameshot = { enable = mkEnableOption "flameshot"; };
    config = mkIf cfg.enable {
        services.flameshot = {
            enable = true;
            settings = {
                General = {
                    saveAfterCopy = false;
                    savePath = "/home/xopc/screenshots";
                    showDesktopNotification = false;
                    startupLaunch = true;
                    uiColor = "#81a1c1";
                    disabledTrayIcon = true;
                    showStartupLaunchMessage = false;
                };
            };
        };
    };
}
