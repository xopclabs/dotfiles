{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.cli.udiskie;
in {
    options.modules.cli.udiskie = { enable = mkEnableOption "udiskie"; };
    config = mkIf cfg.enable {
        services.udiskie = {
            enable = true;
            automount = true;
            notify = false;
            tray = "auto";
        };
    };
}
