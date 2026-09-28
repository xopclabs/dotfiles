{ config, lib, pkgs, tiles, query, period, music, visualizer }:

let
    iconFont = "${config.modules.desktop.shells.noctalia.package}/share/noctalia/assets/fonts/noctalia-tabler.ttf";
    icons = pkgs.runCommand "eww-dashboard-icons" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
        mkdir -p $out
        magick -size 48x48 xc:none -fill '#eceff4' -font ${iconFont} -pointsize 38 -gravity center -annotate +0+0 '︔' $out/lungs.png
        magick -size 48x48 xc:none -fill '#eceff4' -font ${iconFont} -pointsize 38 -gravity center -annotate +0+0 '' $out/temperature.png
        magick -size 48x48 xc:none -fill '#eceff4' -font ${iconFont} -pointsize 38 -gravity center -annotate +0+0 '' $out/plug.png
        magick -size 48x48 xc:none -fill '#eceff4' -font ${iconFont} -pointsize 38 -gravity center -annotate +0+0 '' $out/droplet.png
        magick -size 48x48 xc:none -fill '#eceff4' -font ${iconFont} -pointsize 38 -gravity center -annotate +0+0 '𐀡' $out/bolt.png
    '';
    feedbackIcons = pkgs.runCommand "eww-music-feedback-icons" {} ''
        mkdir -p $out
        for pair in "previous media-skip-backward" "next media-skip-forward" "play media-playback-start" "pause media-playback-pause" "open go-jump"; do
            set -- $pair
            sed 's/#2e3436/#eceff4/g' ${pkgs.adwaita-icon-theme}/share/icons/Adwaita/symbolic/actions/"$2"-symbolic.svg > "$out/$1.svg"
        done
    '';
    plotWidth = tile: tile.width - 56; # 12px padding on each side, 28px axis + 4px gap
    quote = value: builtins.toJSON value;
    alignment = tile:
        if tile.headerAlignment != null then tile.headerAlignment
        else if tile.template == "chart" then "left" else "center";
    listen = tile: let
        initial = if tile.template == "chart" then
            { chart = toString ./empty.svg; high = "—"; low = "—"; legend1 = "—"; legend2 = ""; period = "1h"; }
        else { value = "—"; color = "#d8dee9"; };
        width = if tile.template == "chart" then plotWidth tile else 0;
    in ''
        (deflisten ${tile.id}_data :initial ${quote (builtins.toJSON initial)}
          `${lib.getExe query} listen ${tile.id} ${toString width}`)
    '';
    window = tile: if tile.template == "music" then ''
        (defwindow ${tile.id}
          :monitor ${quote tile.output}
          :geometry (geometry :x "${toString tile.x}px" :y "${toString tile.y}px" :width "${toString tile.width}px" :height "${toString tile.height}px" :anchor "top left")
          :stacking "bottom" :namespace "eww-music-${tile.id}"
          (music-tile :data music_data :bars music_bars :feedback music_feedback :feedback_icons ${quote (toString feedbackIcons)} :bar_width ${toString (tile.width - 24)} :art_size ${if tile.size.rows >= 4 then "138" else "90"} :large ${if tile.size.rows >= 3 then "true" else "false"}))
    '' else ''
        (defwindow ${tile.id}
          :monitor ${quote tile.output}
          :geometry (geometry :x "${toString tile.x}px" :y "${toString tile.y}px" :width "${toString tile.width}px" :height "${toString tile.height}px" :anchor "top left")
          :stacking "bottom" :namespace "eww-telemetry-${tile.id}"
          (${if tile.template == "chart" then "chart-tile" else "value-tile"} :title ${quote tile.title} :icon "${icons}/${tile.icon}.png" :data ${tile.id}_data :header_alignment ${quote (alignment tile)} ${if tile.template == "chart" then '':key ${quote tile.id} :plot_width ${toString (plotWidth tile)}'' else '':compact ${if tile.size.rows == 1 then "true" else "false"}''}))
    '';
in {
    yuck = builtins.replaceStrings
        [ "eww-dashboard-period" "eww-dashboard-music" "eww update" ]
        [ (lib.getExe period) (lib.getExe music) "${lib.getExe pkgs.eww} --config ${config.xdg.configHome}/eww-dashboard update" ]
        (builtins.readFile ./eww.yuck)
        + (if lib.any (tile: tile.template == "music") tiles then ''
            (deflisten music_data :initial ${quote (builtins.toJSON { art = ""; title = "Nothing playing"; artist = ""; playing = false; lyrics0 = { previous = ""; current = ""; next = ""; pending = false; }; lyrics1 = { previous = ""; current = ""; next = ""; pending = false; }; lyric_slot = 0; has_lyrics = false; })} `${lib.getExe music} listen`)
            (deflisten music_bars :initial ${quote (toString ./empty.svg)} `${lib.getExe visualizer} ${toString ((lib.head (lib.filter (tile: tile.template == "music") tiles)).width - 24)}`)
            (defvar music_show_visualizer false)
            (defvar music_feedback "")
          '' else "")
        + "\n" + lib.concatMapStringsSep "\n" listen (lib.filter (tile: tile.template != "music") tiles)
        + "\n" + lib.concatMapStringsSep "\n" window tiles;
    scss = ./eww.scss;
}
