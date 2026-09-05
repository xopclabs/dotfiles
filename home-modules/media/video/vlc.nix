{ inputs, pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.media.video.vlc;
in {
    options.modules.media.video.vlc = { enable = mkEnableOption "vlc"; };
    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            vlc
        ];
    };
}
