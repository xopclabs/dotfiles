{ config, lib, pkgs, tiles, query, period }:

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
    plotWidth = tile: tile.width - 56; # 12px padding on each side, 28px axis + 4px gap
    quote = value: builtins.toJSON value;
    alignment = tile:
        if tile.headerAlignment != null then tile.headerAlignment
        else if tile.template == "chart" then "left" else "center";
    poll = tile: let
        initial = if tile.template == "chart" then
            { chart = toString ./empty.svg; high = "—"; low = "—"; legend1 = "—"; legend2 = ""; period = "1h"; }
        else { value = "—"; color = "#d8dee9"; };
        width = if tile.template == "chart" then plotWidth tile else 0;
    in ''
        (defpoll ${tile.id}_data :interval "60s" :initial ${quote (builtins.toJSON initial)}
          `${lib.getExe query} ${tile.id} ${toString width}`)
    '';
    window = tile: ''
        (defwindow ${tile.id}
          :monitor ${quote tile.output}
          :geometry (geometry :x "${toString tile.x}px" :y "${toString tile.y}px" :width "${toString tile.width}px" :height "${toString tile.height}px" :anchor "top left")
          :stacking "bottom" :namespace "eww-telemetry-${tile.id}"
          (${if tile.template == "chart" then "chart-tile" else "value-tile"} :title ${quote tile.title} :icon "${icons}/${tile.icon}.png" :data ${tile.id}_data :header_alignment ${quote (alignment tile)} ${if tile.template == "chart" then '':key ${quote tile.id} :plot_width ${toString (plotWidth tile)}'' else '':compact ${if tile.size.rows == 1 then "true" else "false"}''}))
    '';
in {
    yuck = builtins.replaceStrings
        [ "eww-dashboard-period" ]
        [ (lib.getExe period) ]
        (builtins.readFile ./eww.yuck)
        + "\n" + lib.concatMapStringsSep "\n" poll tiles
        + "\n" + lib.concatMapStringsSep "\n" window tiles;
    scss = ./eww.scss;
}
