{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.tools.udiskie;
in {
    options.modules.tools.udiskie = { enable = mkEnableOption "udiskie"; };
    config = mkIf cfg.enable {
        services.udiskie = {
            enable = true;
            automount = true;
            notify = false;
            tray = "auto";
        };
    };
}
