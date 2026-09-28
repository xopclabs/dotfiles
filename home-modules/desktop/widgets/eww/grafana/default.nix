{ config, lib, pkgs, ewwConfig }:

let
    grafanaConfig = "${ewwConfig}/queries.json";
in {
    query = pkgs.writeShellScriptBin "eww-dashboard-query" ''
        cache="''${XDG_CACHE_HOME:-$HOME/.cache}/eww-dashboard"
        export PYTHONPATH=${./.}
        if [ "$1" = listen ]; then
            shift
            mode=listen
        else
            mode=once
        fi
        exec ${pkgs.python3}/bin/python3 ${./query.py} \
            "$mode" ${grafanaConfig} "$cache" "$1" "$cache/$1-period" "''${2:-0}"
    '';
    period = pkgs.writeShellScriptBin "eww-dashboard-period" ''
        export PYTHONPATH=${./.}
        exec ${pkgs.python3}/bin/python3 ${./period.py} \
            "$1" ${grafanaConfig} \
            "''${XDG_CACHE_HOME:-$HOME/.cache}/eww-dashboard" \
            ${lib.getExe pkgs.eww} ${ewwConfig} ${../ui/empty.svg}
    '';
    warm = pkgs.writeShellScriptBin "eww-dashboard-warm" ''
        exec ${pkgs.python3}/bin/python3 ${./snapshot.py} \
            ${grafanaConfig} "''${XDG_CACHE_HOME:-$HOME/.cache}/eww-dashboard" \
            ${lib.getExe pkgs.eww} ${ewwConfig}
    '';
}
