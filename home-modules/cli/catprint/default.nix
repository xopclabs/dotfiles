{ config, lib, pkgs, ... }:

let
    cfg = config.modules.cli.catprint;
    package = pkgs.callPackage ./package.nix {};
    configured = pkgs.symlinkJoin {
        name = "catprint-configured";
        paths = [ package ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
            wrapProgram $out/bin/catprint \
                --set-default CATPRINTER_URL ${lib.escapeShellArg cfg.url}
        '';
    };
in {
    options.modules.cli.catprint = {
        enable = lib.mkEnableOption "cat printer HTTP client";
        url = lib.mkOption {
            type = lib.types.str;
            default = "http://192.168.1.155:8858";
            description = "Default cat printer API URL; overridable with CATPRINTER_URL or --url.";
        };
    };

    config = lib.mkIf cfg.enable {
        home.packages = [ configured ];
    };
}
