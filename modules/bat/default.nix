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
            themes = {
                nord = {
                   src = pkgs.fetchFromGitHub {
                     owner = "nordtheme";
                     repo = "sublime-text"; # Bat uses sublime syntax for its themes
                     rev = "91eae63dc83ed501aa133d8f3266c301ab0cbf68";
                     sha256 = "sha256-PrhDhS1bYL+7AHzytOfNhnLIpi8p6WMv9TPsy/arVew=";
                   };
                   file = "Nord.sublime-color-scheme";
                 };
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
