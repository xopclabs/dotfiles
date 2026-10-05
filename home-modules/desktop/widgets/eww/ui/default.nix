{ config, lib, pkgs, tiles, query, period, musicAssets, musicListener }:

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
    musicTiles = lib.filter (tile: tile.template == "music") tiles;
    musicDimensions = tile: {
        width = tile.width - 24;
        height = tile.height - 24;
    };
    musicProfile = tile: pkgs.writeText "zap-music-${tile.id}-layout.json"
        (builtins.toJSON ({ schema = 1; } // musicDimensions tile));
    initialMusic = {
        schema = 1; connected = false; playing = false; track_key = "";
        artist = ""; album = ""; title = "Nothing playing"; art = "";
        elapsed = 0; duration = 0; has_lyrics = false; lyric_slot = 0;
        lyrics0 = { previous = ""; current = ""; next = ""; pending = false; };
        lyrics1 = initialMusic.lyrics0;
        error = ""; feedback = ""; show_visualizer = false; listener_token = "";
        presentation = {
            orientation = "vertical"; art_size = 24; metadata_width = 1;
            lower_visible = false; lower_height = 0;
        };
    };
    initialPreview = {
        schema = 1; visible = false; session_id = ""; selection_revision = 0;
        entity_id = ""; kind = ""; title = ""; artist = "";
        art = ""; loading = false; error = "";
    };
    previewListen = ''
        (deflisten dashboard_zap_preview :initial ${quote (builtins.toJSON initialPreview)}
          `${musicAssets}/listen --channel preview`)
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
    musicListen = tile: ''
        (deflisten ${tile.id}_data :initial ${quote (builtins.toJSON initialMusic)}
          `${lib.getExe musicListener} --instance ${tile.id} --layout-file ${musicProfile tile}`)
        (deflisten ${tile.id}_marquee :initial ${quote (builtins.toJSON {
            schema = 1; track_key = ""; layout_revision = ""; listener_token = "";
            artist = ""; album = "";
        })}
          `${musicAssets}/music-listen --channel marquee --hide-album --instance ${tile.id} --layout-file ${musicProfile tile}`)
        (deflisten ${tile.id}_bars :initial ${quote (toString emptyImage)}
          `${musicAssets}/visualize --instance ${tile.id} --width ${toString (tile.width - 24)} --height 72`)
    '';
    window = tile: if tile.template == "music" then let
        dimensions = musicDimensions tile;
    in ''
        (defwindow ${tile.id}
          :monitor ${quote tile.output}
          :geometry (geometry :x "${toString tile.x}px" :y "${toString tile.y}px" :width "${toString tile.width}px" :height "${toString tile.height}px" :anchor "top left")
          :stacking "bottom" :namespace "eww-music-${tile.id}"
          (box :class "tile music-tile"
            (overlay
              (zap-music-adaptive :state ${tile.id}_data :instance ${quote tile.id}
                :width ${toString dimensions.width} :height ${toString dimensions.height}
                :bars ${tile.id}_bars :show_album false :marquee ${tile.id}_marquee)
              (zap-selection-preview :state dashboard_zap_preview
                :width ${toString dimensions.width} :height ${toString dimensions.height}
                :show_label true))))
    '' else ''
        (defwindow ${tile.id}
          :monitor ${quote tile.output}
          :geometry (geometry :x "${toString tile.x}px" :y "${toString tile.y}px" :width "${toString tile.width}px" :height "${toString tile.height}px" :anchor "top left")
          :stacking "bottom" :namespace "eww-telemetry-${tile.id}"
          (${if tile.template == "chart" then "chart-tile" else "value-tile"} :title ${quote tile.title} :icon "${icons}/${tile.icon}.png" :data ${tile.id}_data :header_alignment ${quote (alignment tile)} ${if tile.template == "chart" then '':key ${quote tile.id} :plot_width ${toString (plotWidth tile)}'' else '':compact ${if tile.size.rows == 1 then "true" else "false"}''}))
    '';
in {
    yuck = lib.optionalString (musicAssets != null) ''(include "${musicAssets}/widgets.yuck")''
        + "\n" + builtins.replaceStrings
            [ "eww-dashboard-period" ] [ (lib.getExe period) ]
            (builtins.readFile ./eww.yuck)
        + lib.optionalString (musicAssets != null) ("\n" + previewListen + "\n" + lib.concatMapStringsSep "\n" musicListen musicTiles)
        + "\n" + lib.concatMapStringsSep "\n" listen (lib.filter (tile: tile.template != "music") tiles)
        + "\n" + lib.concatMapStringsSep "\n" window tiles;
    scss = pkgs.writeText "eww-dashboard.scss" (
        lib.optionalString (musicAssets != null) ''@import "${musicAssets}/widgets.scss";''
        + "\n" + builtins.readFile ./eww.scss);
}
