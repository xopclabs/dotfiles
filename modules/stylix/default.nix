{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.stylix;

in {
    options.modules.stylix = { enable = mkEnableOption "stylix"; };
    config = mkIf cfg.enable {
        stylix = {
            enable = true;
            autoEnable = false;
            base16Scheme = "${pkgs.base16-schemes}/share/themes/nord.yaml";
            targets.gtk.enable = true;
            targets.qt.enable = true;
            targets.mpv.enable = true;
            targets.discord.enable = true;
        };
    };
}
