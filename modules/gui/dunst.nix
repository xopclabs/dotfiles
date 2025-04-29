{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.gui.dunst;

in {
    options.modules.gui.dunst = { enable = mkEnableOption "dunst"; };
    config = mkIf cfg.enable {
        services.dunst = {
            enable = true;
            settings = {
                global = with config.colorScheme.palette; {
                    origin = "top-right";
                    offset = "12x12";
                    separator_height = 2;
                    padding = 12;
                    horizontal_padding = 12;
                    text_icon_padding = 12;
                    frame_width = 4;
                    separator_color = "frame";
                    idle_threshold = 120;
                    font = "Mononoki Nerd Font 12";
                    line_height = 0;
                    format = "<b>%s</b>\n%b";
                    alignment = "left";
                    icon_position = "off";
                    startup_notification = "false";
                    corner_radius = 12;

                    frame_color = "#${base01}";
                    background = "#${base03}";
                    foreground = "#${base05}";
                    timeout = 2;
                };
            };
        };
    };
}
