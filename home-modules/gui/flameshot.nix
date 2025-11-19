{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.gui.flameshot;

in {
    options.modules.gui.flameshot = { enable = mkEnableOption "flameshot"; };
    config = mkIf cfg.enable {
        services.flameshot = {
            enable = true;
            package = (pkgs.flameshot.override { enableWlrSupport = true; });
            settings = {
                General = {
                    disabledTrayIcon = true;
                    showHelp = false;
                    showStartupLaunchMessage = false;
                    saveAfterCopy = true;
                    savePath = "${config.home.homeDirectory}/screenshots";
                    uiColor = "#${config.colorScheme.palette.base0D}";
                    contrastUiColor = "#${config.colorScheme.palette.base05}";
                    contrastOpacity = 40;
                };
            };
        };
    };
} 