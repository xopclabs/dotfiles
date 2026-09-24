{ config, lib, pkgs, ... }:

let
    cfg = config.modules.desktop.widgets.eww;
    ewwConfig = "${config.xdg.configHome}/eww-dashboard";
    iconFont = "${config.modules.desktop.shells.noctalia.package}/share/noctalia/assets/fonts/noctalia-tabler.ttf";
    icons = pkgs.runCommand "eww-dashboard-icons" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
        mkdir -p $out
        magick -size 48x48 xc:none -fill '#eceff4' -font ${iconFont} -pointsize 38 -gravity center -annotate +0+0 '︔' $out/lungs.png
        magick -size 48x48 xc:none -fill '#eceff4' -font ${iconFont} -pointsize 38 -gravity center -annotate +0+0 '' $out/temperature.png
        magick -size 48x48 xc:none -fill '#eceff4' -font ${iconFont} -pointsize 38 -gravity center -annotate +0+0 '' $out/plug.png
        magick -size 48x48 xc:none -fill '#eceff4' -font ${iconFont} -pointsize 38 -gravity center -annotate +0+0 '' $out/droplet.png
        magick -size 48x48 xc:none -fill '#eceff4' -font ${iconFont} -pointsize 38 -gravity center -annotate +0+0 '𐀡' $out/bolt.png
    '';
    query = pkgs.writeShellScriptBin "eww-dashboard-query" ''
        cache="''${XDG_CACHE_HOME:-$HOME/.cache}/eww-dashboard"
        exec ${pkgs.python3}/bin/python3 ${./query.py} \
            ${config.xdg.configHome}/noctalia/grafana-widgets.json \
            "$cache" "$1" "$cache/$1-period"
    '';
    period = pkgs.writeShellScriptBin "eww-dashboard-period" ''
        exec ${pkgs.python3}/bin/python3 ${./period.py} \
            "$1" ${config.xdg.configHome}/noctalia/grafana-widgets.json \
            "''${XDG_CACHE_HOME:-$HOME/.cache}/eww-dashboard" \
            ${lib.getExe pkgs.eww} ${ewwConfig}
    '';
    launch = pkgs.writeShellScriptBin "eww-dashboard" ''
        eww=${lib.getExe pkgs.eww}
        config=${ewwConfig}
        "$eww" --config "$config" daemon >/dev/null 2>&1 || true
        "$eww" --config "$config" open-many co2_chart temperature_chart humidity_value today_power power_chart
        "$eww" --config "$config" poll co2_data temperature_data humidity_data today_power_data power_data
    '';
in {
    options.modules.desktop.widgets.eww.enable = lib.mkEnableOption "Eww telemetry widgets";

    config = lib.mkIf cfg.enable {
        home.packages = [ pkgs.eww query period launch ];
        xdg.configFile."eww-dashboard/eww.yuck".text = builtins.replaceStrings
            [ "eww-dashboard-query" "eww-dashboard-period" "@EMPTY_CHART@" "@ICONS@" ]
            [ (lib.getExe query) (lib.getExe period) (toString ./empty.svg) (toString icons) ]
            (builtins.readFile ./eww.yuck);
        xdg.configFile."eww-dashboard/eww.scss".source = ./eww.scss;
    };
}
