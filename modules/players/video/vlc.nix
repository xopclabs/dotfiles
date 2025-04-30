{ inputs, pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.players.video.vlc;
in {
    options.modules.players.video.vlc = { enable = mkEnableOption "vlc"; };
    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            vlc
        ];
    };
}
