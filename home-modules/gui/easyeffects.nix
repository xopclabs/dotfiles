{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.gui.easyeffects;

in {
    options.modules.gui.easyeffects = { enable = mkEnableOption "easyeffects"; };
    config = mkIf cfg.enable {
        services.easyeffects = {
            enable = true;
        };
    };
}
