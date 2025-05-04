{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.cli.bat;

in {
    options.modules.cli.bat = { enable = mkEnableOption "bat"; };
    config = mkIf cfg.enable {
        programs.bat = {
            enable = true;
            config = {
                style = "numbers,changes,header";
            };
            extraPackages = with pkgs.bat-extras; [
                batdiff
                batman
                batgrep
                batwatch
            ];
        };
    };
} 
