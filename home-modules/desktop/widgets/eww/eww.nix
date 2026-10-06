args@{ config, lib, pkgs, ... }:

let
    cfg = config.modules.desktop.widgets.eww;
    layouts = { internal-monitor-dashboard = import ./layouts/internal-monitor-dashboard.nix; };
    grid = cfg.grid;
    pixels = value: builtins.fromJSON (lib.removeSuffix "px" value);
    unit = pixels grid.unit;
    horizontalGap = pixels grid.gap.horizontal;
    verticalGap = pixels grid.gap.vertical;
    horizontalMargin = pixels grid.margin.horizontal;
    verticalMargin = pixels grid.margin.vertical;
    place = id: tile: tile // {
        id = "${cfg.page}_${id}";
        x = horizontalMargin + tile.position.col * (unit + horizontalGap);
        y = verticalMargin + tile.position.row * (unit + verticalGap);
        width = tile.size.cols * unit + (tile.size.cols - 1) * horizontalGap;
        height = tile.size.rows * unit + (tile.size.rows - 1) * verticalGap;
    };
    widgets = (cfg.pages.${cfg.page} or { widgets = {}; }).widgets;
    tiles = lib.mapAttrsToList place widgets;
    isTelemetry = tile: lib.elem tile.template [ "chart" "value" ];
    musicTiles = lib.filter (tile: tile.template == "zap-music") tiles;
    pickerTiles = lib.filter (tile: tile.template == "zap-picker") tiles;
    previewTiles = lib.filter (tile: tile.template == "zap-selection-preview") tiles;
    picker = if pickerTiles == [] then null else builtins.head pickerTiles;
    overlayTarget = tile: "${cfg.page}_${tile.overlay}";
    ordinaryTiles = lib.filter (tile: tile.template != "zap-picker" && tile.overlay == null) tiles;
    occupied = lib.concatMap (tile:
        lib.concatMap (row:
            map (col: "${toString row}:${toString col}")
                (lib.range tile.position.col (tile.position.col + tile.size.cols - 1)))
            (lib.range tile.position.row (tile.position.row + tile.size.rows - 1))) ordinaryTiles;
    ewwConfig = "${config.xdg.configHome}/eww-dashboard";
    grafana = import ./grafana { inherit config lib pkgs ewwConfig; };
    queries = (import ./grafana/config.nix { inherit config; }) // {
        instances = lib.listToAttrs (map (tile: {
            name = tile.id;
            value = { inherit (tile) source template; field = tile.field; };
        }) (lib.filter isTelemetry tiles));
    };
    zap = args.zap or null;
    hasZap = musicTiles != [] || pickerTiles != [] || previewTiles != [];
    zapEnabled = lib.attrByPath [ "programs" "zap" "enable" ] false config;
    zapUi = if hasZap && zap != null && zapEnabled then zap.lib.mkEwwIntegration {
        inherit pkgs;
        configFile = toString config.xdg.configFile."zap/config.json".source;
        ewwConfigDirectory = ewwConfig;
        music = map (tile: {
            inherit (tile) id;
            window = tile.id;
            layout = { inherit (tile) width height inset; };
            inherit (tile) showAlbum;
        }) musicTiles;
        previews = map (tile: {
            inherit (tile) id showLabel;
            window = if tile.overlay == null then tile.id else overlayTarget tile;
            layout = { inherit (tile) width height inset; };
        }) previewTiles;
        picker = if picker == null then null else {
            inherit (picker) id;
            window = picker.id;
            layout = { inherit (picker) width height; };
        };
    } else null;
    ui = import ./ui {
        inherit config lib pkgs tiles zapUi picker isTelemetry overlayTarget;
        inherit (grafana) query period;
    };
    launch = pkgs.writeShellScriptBin "eww-dashboard" ''
        exec ${pkgs.bash}/bin/bash ${./launch.sh} \
            ${lib.getExe pkgs.eww} ${ewwConfig} ${pkgs.util-linux}/bin/flock \
            ${lib.getExe grafana.warm} "$@" -- ${lib.escapeShellArgs (map (tile: tile.id) ordinaryTiles)}
    '';
in {
    options.modules.desktop.widgets.eww = {
        enable = lib.mkEnableOption "Eww telemetry widgets";

        layout = lib.mkOption {
            type = lib.types.nullOr (lib.types.enum (builtins.attrNames layouts));
            default = null;
            description = "Named Eww tile layout.";
        };

        grid = {
            rows = lib.mkOption { type = lib.types.ints.positive; default = 6; description = "Grid row count."; };
            cols = lib.mkOption { type = lib.types.ints.positive; default = 10; description = "Grid column count."; };
            unit = lib.mkOption { type = lib.types.strMatching "[1-9][0-9]*px"; default = "78px"; description = "Size of 1U in logical pixels."; };
            gap = {
                horizontal = lib.mkOption { type = lib.types.strMatching "(0|[1-9][0-9]*)px"; default = "16px"; description = "Space between columns in logical pixels."; };
                vertical = lib.mkOption { type = lib.types.strMatching "(0|[1-9][0-9]*)px"; default = "8px"; description = "Space between rows in logical pixels."; };
            };
            margin = {
                horizontal = lib.mkOption { type = lib.types.strMatching "(0|[1-9][0-9]*)px"; default = "18px"; description = "Left and right outer margin in logical pixels."; };
                vertical = lib.mkOption { type = lib.types.strMatching "(0|[1-9][0-9]*)px"; default = "16px"; description = "Top and bottom outer margin in logical pixels."; };
            };
        };

        page = lib.mkOption { type = lib.types.str; default = "main"; description = "Page to display; workspace selection can be wired here later."; };

        pages = lib.mkOption {
            default = {};
            description = "Dashboard pages containing independently placed widget instances.";
            type = lib.types.attrsOf (lib.types.submodule ({ ... }: {
                options.widgets = lib.mkOption {
                    default = {};
                    type = lib.types.attrsOf (lib.types.submodule ({ ... }: {
                        options = {
                            source = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "Grafana source key; unused for zap widgets."; };
                            template = lib.mkOption { type = lib.types.enum [ "chart" "value" "zap-music" "zap-picker" "zap-selection-preview" ]; };
                            overlay = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "For zap-selection-preview, explicitly overlay this page's named zap-music widget instead of creating a window. Geometry must match its target."; };
                            inset = lib.mkOption { type = lib.types.ints.unsigned; default = 0; description = "Host padding in logical pixels for zap music/preview."; };
                            showAlbum = lib.mkOption { type = lib.types.bool; default = false; description = "Show the album in zap-music."; };
                            showLabel = lib.mkOption { type = lib.types.bool; default = false; description = "Show the title in zap-selection-preview."; };
                            headerAlignment = lib.mkOption {
                                type = lib.types.nullOr (lib.types.enum [ "left" "center" ]);
                                default = null;
                                description = "Header alignment; defaults to left for charts and center for values.";
                            };
                            field = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "Named source field to show in a value widget; null selects the first."; };
                            title = lib.mkOption { type = lib.types.str; default = ""; };
                            icon = lib.mkOption { type = lib.types.str; default = ""; description = "Name of a generated icon PNG."; };
                            output = lib.mkOption { type = lib.types.str; description = "Eww monitor name."; };
                            position = lib.mkOption {
                                type = lib.types.submodule {
                                    options = {
                                        row = lib.mkOption { type = lib.types.int; };
                                        col = lib.mkOption { type = lib.types.int; };
                                    };
                                };
                            };
                            size = lib.mkOption {
                                type = lib.types.submodule {
                                    options = {
                                        rows = lib.mkOption { type = lib.types.int; };
                                        cols = lib.mkOption { type = lib.types.int; };
                                    };
                                };
                            };
                        };
                    }));
                };
            }));
        };
    };

    config = lib.mkIf cfg.enable ({
        modules.desktop.widgets.eww.pages.main.widgets = lib.mkIf (cfg.layout != null)
            (lib.mapAttrs (_: widget: lib.mapAttrs (_: lib.mkDefault) widget) layouts.${cfg.layout});

        assertions = [ {
            assertion = !hasZap || (zap != null && zapEnabled);
            message = "Explicit Eww zap widgets require the zap flake input and enabled programs.zap.";
        } {
            assertion = lib.length pickerTiles <= 1 && lib.all (tile:
                tile.overlay == null || (tile.template == "zap-selection-preview" && lib.any (target:
                    target.id == overlayTarget tile && target.output == tile.output
                    && target.position == tile.position && target.size == tile.size
                    && target.inset == tile.inset) musicTiles)) tiles;
            message = "Declare at most one zap-picker; preview overlays must explicitly name a zap-music widget with matching output, geometry and inset.";
        } {
            assertion = builtins.hasAttr cfg.page cfg.pages
                && lib.all (tile:
                    (if !isTelemetry tile then tile.source == null
                     else if tile.template == "chart" then tile.source != null && builtins.hasAttr tile.source queries.charts
                     else tile.source != null && (builtins.hasAttr tile.source queries.values || builtins.hasAttr tile.source queries.charts))
                    && (tile.field == null || (tile.template == "value" &&
                        (if builtins.hasAttr tile.source queries.charts then
                            lib.any (series: series.field == tile.field) queries.charts.${tile.source}.series
                         else tile.field == "value")))) tiles
                && lib.all (tile:
                    tile.position.row >= 0 && tile.position.col >= 0
                    && tile.size.rows > 0 && tile.size.cols > 0
                    && tile.position.row + tile.size.rows <= grid.rows
                    && tile.position.col + tile.size.cols <= grid.cols
                    && (tile.template != "chart" || (tile.size.rows >= 2 && tile.size.cols >= 3))) tiles
                && lib.length (lib.unique occupied) == lib.length occupied;
            message = "Eww tiles need a matching telemetry source (zap widgets use none), must fit the grid, and non-popup/non-overlay widgets must not overlap. Trends need at least 2 rows and 3 columns.";
        } ];

        sops.secrets = {
            "eww/grafana-token" = {
                sopsFile = ../../../../secrets/hosts/pc.yaml;
                # Reuse the existing Grafana service token; no new credential needed.
                key = "grafana/noctalia-token";
            };
            "eww/grafana-domain" = {
                sopsFile = ../../../../secrets/shared/selfhost.yaml;
                key = "domain";
            };
        };

        home.packages = [ pkgs.eww grafana.query grafana.period launch ];

        xdg.configFile."eww-dashboard/queries.json".text = builtins.toJSON queries;
        xdg.configFile."eww-dashboard/eww.yuck".text = ui.yuck;
        xdg.configFile."eww-dashboard/eww.scss".source = ui.scss;
    } // lib.optionalAttrs (zap != null) {
        programs.zap.settings.popup = lib.mkIf (picker != null && zapEnabled) (
            if picker == null || zapUi == null then {} else {
                output = picker.output;
                renderer = zapUi.picker.rendererSettings;
            });
    });
}
