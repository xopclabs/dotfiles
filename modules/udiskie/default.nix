{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.udiskie;
in {
    options.modules.udiskie = { enable = mkEnableOption "udiskie"; };
    config = mkIf cfg.enable {
        services.udiskie = {
            enable = true;
            automount = true;
            tray = "always";
            notify = true;
        };
    };
}
