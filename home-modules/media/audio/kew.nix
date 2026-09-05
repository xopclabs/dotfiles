{ inputs, pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.media.audio.kew;
in {
    options.modules.media.audio.kew = { enable = mkEnableOption "kew"; };
    config = mkIf cfg.enable {
        home.packages = [
            pkgs.kew
        ];
    };
}
