{ config, ... }:
let
  monitor1 = "eDP-1";
  monitor2 = "HDMI-A-2";
in 
{
    # Wallpaper
    home.file.".config/hypr/wallpaper" = {
        recursive = true;
        source = ./wallpaper;
    };
    home.file.".config/hypr/hyprpaper.conf".text = ''
        preload = ${config.xdg.configHome}/hypr/wallpaper/nord.png
        wallpaper = ${monitor1},${config.xdg.configHome}/hypr/wallpaper/nord.png
        wallpaper = ${monitor2},${config.xdg.configHome}/hypr/wallpaper/nord.png
        splash = false
        ipc = off
    '';
}
