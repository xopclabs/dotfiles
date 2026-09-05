{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.media.audio.feishin;
in {
    options.modules.media.audio.feishin = { enable = mkEnableOption "feishin"; };
    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            feishin
        ];
    };
}
