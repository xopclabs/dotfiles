{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.tools.nh;

in {
    options.modules.tools.nh = { 
        enable = mkEnableOption "nh"; 
    };
    config = mkIf cfg.enable {
        programs.nh = {
            enable = true;
        };
    };
}
