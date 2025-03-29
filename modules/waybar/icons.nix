{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.waybar;
in {
    config = mkIf cfg.enable {
        programs.waybar = {
            settings.mainBar."hyprland/workspaces" = {
                window-rewrite-default = "󱗜";
                window-rewrite = {
                    "title<.*YouTube.*>" = "󰗃";
                    "title<.*Dreaming Spanish.*>" = "";
                    "class<firefox>" = "󰈹";
                    "class<floorp>" = "󰈹";
                    "class<kitty>" = "";
                    "class<Vncviewer>" = "󰢹";
                    "class<Cursor>" = "󰨞";
                    "class<code(-url-handler)?>" = "󰨞";
                    "class<org\\.telegram\\.desktop>" = "";
                    "class<libreoffice-calc>" = "󰈛";
                    "class<Transmission>" = "";
                    "class<com\\.obsproject\\.studio>" = "";
                    "class<pavucontrol>" = "󰕾";
                    "class<blueman>" = "";
                    "class<chromium-browser>" = "";
                    "class<Chromium-browser>" = "";
                    "class<yazi>" = "";
                    "class<ranger>" = "";
                    "class<(kitty|ranger)> title<ranger.*>" = "";
                    "class<(kitty|yazi)> title<yazi.*>" = "";
                    "class<mpv>" = "";
                    "class<rofi>" = "󱄅";
                    "class<firefox> title<.*Slack.*>" = "󰒱";
                    "class<Slack>" = "󰒱";
                    "class<Steam> title<.+>" = "󰓓";
                    "class<com\\.moonlight_stream\\.Moonlight>" = "󰊗";
                    "class<Spotify>" = "";
                    "title<.*discord.*>" = "󰙯";
                };
            };
        };
    };
}
