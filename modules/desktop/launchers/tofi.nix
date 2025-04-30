{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.desktop.launchers.tofi;
in {
    options.modules.desktop.launchers.tofi = {
        enable = mkEnableOption "tofi launcher";
    };
    
    config = mkIf cfg.enable {
        programs.tofi = {
            enable = true;
            settings = with config.colorScheme.palette; let
                padding = 8; 
                waybar-width = 42;
            in {
                drun-launch = false;
                history = true;
                terminal = config.modules.terminals.default;
                late-keyboard-init = false;
                multi-instance = false;

                # Theme
                anchor = "top-left";
                width = 1920 - waybar-width;
                height = waybar-width;
                horizontal = true;
                # Padding
                padding-top = padding;
                padding-bottom = padding;
                padding-left = padding;
                padding-right = 0;
                margin-top = 0;
                margin-bottom = 0;
                margin-left = waybar-width;
                margin-right = 0;
                # Fonts
                font = "monospace";
                font-size = 16;
                min-input-width = 120;
                result-spacing = padding * 6;
                # Prompt
                prompt-text = " ";
                prompt-padding = padding * 3;
                prompt-color = "#${base06}";
                # Input
                input-color = "#${base06}";
                input-background = "#${base01}";
                input-background-padding = padding;
                input-background-corner-radius = 0;
                # Result color
                default-result-color = "#${base04}";
                # Selection text
                selection-color = "#${base06}";
                selection-match-color = "#${base04}";
                selection-background = "#${base0F}";
                selection-background-padding = padding;
                # Border
                border-width = 0;
                border-color = "#${base0D}";
                outline-width = 0;
                # Colors
                background-color = "#${base00}";
                text-color = "#${base06}";
            };
        };
    };
}
