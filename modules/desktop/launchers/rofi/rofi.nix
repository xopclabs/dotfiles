{ inputs, lib, config, pkgs, ... }:
with lib;
let
    cfg = config.modules.desktop.launchers.rofi;

    launcher_type = "type-1";
    launcher_style = "style-10";
    powermenu_type = "type-1";
    powermenu_style = "style-10";

    launcher = pkgs.writeShellScriptBin "rofi-drun" ''
        ${config.xdg.configHome}/rofi/launchers/${launcher_type}/launcher.sh ${launcher_style}
    '';
    powermenu = pkgs.writeShellScriptBin "powermenu" ''
        ${config.xdg.configHome}/rofi/powermenu/${powermenu_type}/powermenu.sh ${powermenu_style}
    '';
in {
    options.modules.desktop.launchers.rofi = { enable = mkEnableOption "rofi"; };
    config = mkIf cfg.enable {
        programs.rofi = {
            enable = true;
            package = pkgs.rofi-wayland;
        };
        home.file.".config/rofi" = {
            source =  ./rofi;
            recursive = true;
        };
        home.file.".config/rofi/colors/nix.rasi".text = with config.colorScheme.palette; ''
            * {
                background:     #${base00}FF;
                background-alt: #${base02}FF;
                foreground:     #${base06}FF;
                selected:       #${base0F}FF;
                active:         #${base0B}FF;
                urgent:         #${base08}FF;
            }
        '';
        home.packages = [
            launcher
            powermenu
        ];
    };
}
