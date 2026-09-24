{ config, lib, pkgs, ewwConfig }:

let
    grafanaConfig = "${ewwConfig}/queries.json";
in {
    query = pkgs.writeShellScriptBin "eww-dashboard-query" ''
        cache="''${XDG_CACHE_HOME:-$HOME/.cache}/eww-dashboard"
        exec ${pkgs.python3}/bin/python3 ${./query.py} \
            ${grafanaConfig} "$cache" "$1" "$cache/$1-period" "''${2:-0}"
    '';
    period = pkgs.writeShellScriptBin "eww-dashboard-period" ''
        exec ${pkgs.python3}/bin/python3 ${./period.py} \
            "$1" ${grafanaConfig} \
            "''${XDG_CACHE_HOME:-$HOME/.cache}/eww-dashboard" \
            ${lib.getExe pkgs.eww} ${ewwConfig}
    '';
}
