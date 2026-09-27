{ config, lib, pkgs, ... }:

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
        inherit id;
        x = horizontalMargin + tile.position.col * (unit + horizontalGap);
        y = verticalMargin + tile.position.row * (unit + verticalGap);
        width = tile.size.cols * unit + (tile.size.cols - 1) * horizontalGap;
        height = tile.size.rows * unit + (tile.size.rows - 1) * verticalGap;
    };
    tiles = lib.mapAttrsToList place cfg.tiles;
    occupied = lib.concatMap (tile:
        lib.concatMap (row:
            map (col: "${toString row}:${toString col}")
                (lib.range tile.position.col (tile.position.col + tile.size.cols - 1)))
            (lib.range tile.position.row (tile.position.row + tile.size.rows - 1))) tiles;
    ewwConfig = "${config.xdg.configHome}/eww-dashboard";
    grafana = import ./grafana { inherit config lib pkgs ewwConfig; };
    queries = import ./grafana/config.nix { inherit config; };
    ui = import ./ui { inherit config lib pkgs tiles; inherit (grafana) query period; };
    launch = pkgs.writeShellScriptBin "eww-dashboard" ''
        exec ${pkgs.bash}/bin/bash ${./launch.sh} \
            ${lib.getExe pkgs.eww} ${ewwConfig} ${pkgs.util-linux}/bin/flock \
            ${lib.getExe grafana.warm} "$@" -- ${lib.escapeShellArgs (map (tile: tile.id) tiles)}
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

        tiles = lib.mkOption {
            default = {};
            description = "Tiles in the selected layout; individual fields can be overridden per host.";
            type = lib.types.attrsOf (lib.types.submodule ({ ... }: {
                options = {
                    key = lib.mkOption { type = lib.types.str; description = "Eww query key and poll name."; };
                    type = lib.mkOption { type = lib.types.enum [ "chart" "value" ]; };
                    title = lib.mkOption { type = lib.types.str; };
                    icon = lib.mkOption { type = lib.types.str; description = "Name of a generated icon PNG."; };
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
    };

    config = lib.mkIf cfg.enable {
        modules.desktop.widgets.eww.tiles = lib.mkIf (cfg.layout != null)
            (lib.mapAttrs (_: tile: lib.mapAttrs (_: lib.mkDefault) tile) layouts.${cfg.layout});

        assertions = [ {
            assertion = lib.length (lib.unique (map (tile: tile.key) tiles)) == lib.length tiles
                && lib.all (tile:
                    tile.position.row >= 0 && tile.position.col >= 0
                    && tile.size.rows > 0 && tile.size.cols > 0
                    && tile.position.row + tile.size.rows <= grid.rows
                    && tile.position.col + tile.size.cols <= grid.cols
                    && (tile.type != "chart" || (tile.size.rows >= 2 && tile.size.cols >= 3))) tiles
                && lib.length (lib.unique occupied) == lib.length occupied;
            message = "Eww tiles must have unique data keys, fit without overlap on the configured grid, and charts need at least 2 rows and 3 columns.";
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
    };
}
