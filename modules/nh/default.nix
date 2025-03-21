{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.nh;

in {
    options.modules.nh = { 
        enable = mkEnableOption "nh"; 
    };
    config = mkIf cfg.enable {
        programs.nh = {
            enable = true;
            clean = {
                enable = true;
                dates = "weekly";
                extraArgs = "--delete-older-than 7d";
            };
        };
    };
}
