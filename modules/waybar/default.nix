{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.waybar;
in {
    options.modules.waybar = { enable = mkEnableOption "waybar"; };
    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            waybar
        ];
        programs.waybar.enable = true;
        home.file.".config/waybar/style.css".source = ./style.css;
        home.file.".config/waybar/config.jsonc".source = ./config.jsonc;
    };
}
