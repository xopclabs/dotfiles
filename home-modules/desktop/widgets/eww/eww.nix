{ config, lib, pkgs, ... }:

let
    cfg = config.modules.desktop.widgets.eww;
    layouts = { internal-monitor-dashboard = import ./layouts/internal-monitor-dashboard.nix; };
    tiles = lib.mapAttrsToList (id: tile: tile // { inherit id; }) cfg.tiles;
    ewwConfig = "${config.xdg.configHome}/eww-dashboard";
    grafana = import ./grafana { inherit config lib pkgs ewwConfig; };
    queries = import ./grafana/config.nix { inherit config; };
    ui = import ./ui { inherit config lib pkgs tiles; inherit (grafana) query period; };
    launch = pkgs.writeShellScriptBin "eww-dashboard" ''
        exec ${pkgs.bash}/bin/bash ${./launch.sh} \
            ${lib.getExe pkgs.eww} ${ewwConfig} ${pkgs.util-linux}/bin/flock \
            "$@" -- ${lib.escapeShellArgs (map (tile: tile.id) tiles)}
    '';
in {
    options.modules.desktop.widgets.eww = {
        enable = lib.mkEnableOption "Eww telemetry widgets";

        layout = lib.mkOption {
            type = lib.types.nullOr (lib.types.enum (builtins.attrNames layouts));
            default = null;
            description = "Named Eww tile layout.";
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
                    x = lib.mkOption { type = lib.types.int; };
                    y = lib.mkOption { type = lib.types.int; };
                    width = lib.mkOption { type = lib.types.int; };
                    height = lib.mkOption { type = lib.types.int; };
                };
            }));
        };
    };

    config = lib.mkIf cfg.enable {
        modules.desktop.widgets.eww.tiles = lib.mkIf (cfg.layout != null)
            (lib.mapAttrs (_: tile: lib.mapAttrs (_: lib.mkDefault) tile) layouts.${cfg.layout});

        assertions = [ {
            assertion = lib.length (lib.unique (map (tile: tile.key) tiles)) == lib.length tiles
                && lib.all (tile: tile.type != "chart" || tile.width > 56) tiles;
            message = "Eww tiles need unique data keys and chart widths greater than 56px.";
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
