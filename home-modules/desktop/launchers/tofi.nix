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
                bar-width = if (config.modules.desktop.bars.waybar.enable
                    || config.modules.desktop.bars.noctalia.enable) then 42 else 0;
            in {
                drun-launch = true;
                history = true;
                terminal = config.modules.terminals.default;
                late-keyboard-init = false;
                multi-instance = false;

                # Theme
                # `top` anchors left+right so width 0 is assigned by the compositor.
                # A hardcoded 1920px width matches the external and gets stretched
                # on the 800px internal panel (niri scales the buffer to the output).
                anchor = "top";
                width = 0;
                height = 42;
                horizontal = true;
                # Padding
                padding-top = padding;
                padding-bottom = padding;
                padding-left = padding;
                padding-right = 0;
                margin-top = 0;
                margin-bottom = 0;
                margin-left = bar-width;
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
