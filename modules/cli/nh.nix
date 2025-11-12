{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.cli.nh;

in {
    options.modules.cli.nh = { 
        enable = mkEnableOption "nh"; 
    };
    config = mkIf cfg.enable {
        programs.nh = {
            enable = true;
        };
    };
}
