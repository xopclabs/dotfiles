{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.xdg;

in {
    options.modules.xdg = { enable = mkEnableOption "xdg"; };
    config = mkIf cfg.enable {
        xdg.userDirs = {
            enable = true;
            documents = "$HOME/other/";
            download = "$HOME/downloads/";
            videos = "$HOME/other/";
            music = "$HOME/music/";
            pictures = "$HOME/pictures/";
            desktop = "$HOME/other/";
            publicShare = "$HOME/other/";
            templates = "$HOME/other/";
        };
    };
}
