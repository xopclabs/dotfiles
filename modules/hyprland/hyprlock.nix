{ config, ... }:
let
  monitor1 = "eDP-1";
in 
{
    programs.hyprlock = with config.colorScheme.palette;
    let
        text_color = "rgba(${base04}FF)";
        entry_background_color = "rgba(${base01}FF)";
        entry_border_color = "rgba(${base0D}FF)";
        entry_color = "rgba(${base04}FF)";
        font_family = "Mononoki Nerd Font";
        font_family_clock = "Mononoki Nerd Font";
    in { 
        enable = false;
        backgrounds = [
            {
                path = "screenshot";
                blur_size = 7;
                blur_passes = 4;
            }
        ];
        input-fields = [
            {
                monitor = monitor1;
                size = {width = 250; height = 50;};
                outline_thickness = 2;
                dots_size = 0.1;
                dots_spacing = 0.3;
                outer_color = entry_border_color;
                inner_color = entry_background_color;
                font_color = entry_color;
                rounding = 8;
                position = {x = 0; y = 20;};
                halign = "center";
                valign = "center";
            } 
        ];

        labels = [
            {
                monitor = "";
                text = "$TIME";
                color = text_color;
                font_size = 65;
                font_family = font_family_clock;
                position = {x = 0; y = 300;};
                halign = "center";
                valign = "center";
            }
            { # "locked" text
                monitor = "";
                text = "locked";
                color = text_color;
                font_size = 14;
                font_family = font_family;
                position = {x = 0; y= 50;};
                halign = "center";
                valign = "bottom";
            }
        ];
    };
}
