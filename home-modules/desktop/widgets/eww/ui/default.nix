{ config, lib, pkgs, tiles, query, period, zapUi, picker, isTelemetry, overlayTarget }:

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
    emptyImage = pkgs.writeText "eww-dashboard-empty.svg" (builtins.readFile ./empty.svg);
    pickerWindow = lib.optionalString (picker != null) ''
        (defwindow ${picker.id} [zap_session]
          :geometry (geometry :x "${toString picker.x}px" :y "${toString picker.y}px" :width "${toString picker.width}px" :height "${toString picker.height}px" :anchor "top left")
          :stacking "overlay" :focusable "none" :exclusive false
          ${zapUi.picker.widget})
    '';
    plotWidth = tile: tile.width - 56;
    quote = value: builtins.toJSON value;
    alignment = tile:
        if tile.headerAlignment != null then tile.headerAlignment
        else if tile.template == "chart" then "left" else "center";
    listen = tile: let
        initial = if tile.template == "chart" then
            { chart = toString emptyImage; high = "—"; low = "—"; legend1 = "—"; legend2 = ""; period = "1h"; }
        else { value = "—"; color = "#d8dee9"; };
        width = if tile.template == "chart" then plotWidth tile else 0;
    in ''
        (deflisten ${tile.id}_data :initial ${quote (builtins.toJSON initial)}
          `${lib.getExe query} listen ${tile.id} ${toString width}`)
    '';
    musicWidget = tile: let
        previews = lib.filter (preview: preview.overlay != null && overlayTarget preview == tile.id) tiles;
        widget = zapUi.music.${tile.id}.widget;
    in if previews == [] then widget else ''(overlay ${widget} ${lib.concatMapStringsSep " " (preview: zapUi.previews.${preview.id}.widget) previews})'';
    window = tile: if tile.template == "zap-picker" || tile.overlay != null then "" else if tile.template == "zap-music" then ''
        (defwindow ${tile.id}
          :monitor ${quote tile.output}
          :geometry (geometry :x "${toString tile.x}px" :y "${toString tile.y}px" :width "${toString tile.width}px" :height "${toString tile.height}px" :anchor "top left")
          :stacking "bottom" :namespace "eww-music-${tile.id}"
          (box :class "tile music-tile" :style "padding: ${toString tile.inset}px;"
            ${musicWidget tile}))
    '' else if tile.template == "zap-selection-preview" then ''
        (defwindow ${tile.id}
          :monitor ${quote tile.output}
          :geometry (geometry :x "${toString tile.x}px" :y "${toString tile.y}px" :width "${toString tile.width}px" :height "${toString tile.height}px" :anchor "top left")
          :stacking "bottom" :namespace "eww-zap-preview-${tile.id}"
          (box :style "padding: ${toString tile.inset}px;"
            ${zapUi.previews.${tile.id}.widget}))
    '' else ''
        (defwindow ${tile.id}
          :monitor ${quote tile.output}
          :geometry (geometry :x "${toString tile.x}px" :y "${toString tile.y}px" :width "${toString tile.width}px" :height "${toString tile.height}px" :anchor "top left")
          :stacking "bottom" :namespace "eww-telemetry-${tile.id}"
          (${if tile.template == "chart" then "chart-tile" else "value-tile"} :title ${quote tile.title} :icon "${icons}/${tile.icon}.png" :data ${tile.id}_data :header_alignment ${quote (alignment tile)} ${if tile.template == "chart" then '':key ${quote tile.id} :plot_width ${toString (plotWidth tile)}'' else '':compact ${if tile.size.rows == 1 then "true" else "false"}''}))
    '';
in {
    yuck = lib.optionalString (zapUi != null) ''
        (include "${zapUi.assets}/widgets.yuck")
        (include "${zapUi.assets}/listeners.yuck")
        ${pickerWindow}
    ''
        + "\n" + builtins.replaceStrings
            [ "eww-dashboard-period" ] [ (lib.getExe period) ]
            (builtins.readFile ./eww.yuck)
        + "\n" + lib.concatMapStringsSep "\n" listen (lib.filter isTelemetry tiles)
        + "\n" + lib.concatMapStringsSep "\n" window tiles;
    scss = pkgs.writeText "eww-dashboard.scss" (
        lib.optionalString (zapUi != null) ''@import "${zapUi.assets}/widgets.scss";''
        + "\n" + builtins.readFile ./eww.scss);
}
