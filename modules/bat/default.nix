{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.bat;

in {
    options.modules.bat = { enable = mkEnableOption "bat"; };
    config = mkIf cfg.enable {
        programs.bat = {
            enable = true;
            config = {
                theme = "Nord";
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