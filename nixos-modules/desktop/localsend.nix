{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.desktop.localsend;
in
{
    options.desktop.localsend = {
        enable = mkEnableOption "LocalSend file sharing";

        openFirewall = mkOption {
            type = types.bool;
            default = true;
            description = "Open firewall ports for LocalSend";
        };
    };

    config = mkIf cfg.enable {
        programs.localsend = {
            enable = true;
            openFirewall = cfg.openFirewall;
        };
    };
}

