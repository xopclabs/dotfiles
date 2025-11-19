{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.desktop.wireguard;
in
{
    options.desktop.wireguard = {
        enable = mkEnableOption "WireGuard VPN client";

        peers = mkOption {
            type = types.attrsOf (types.submodule {
                options = {
                    name = mkOption {
                        type = types.str;
                        description = "Name of the peer";
                    };
                    enable = mkOption {
                        type = types.bool;
                        default = true;
                        description = "Enable this peer";
                    };
                    autostart = mkEnableOption "Autostart this peer";
                };
            });
            default = {};
            description = "WireGuard peers configuration";
        };
    };

    config = mkIf cfg.enable {
        # For each peer, create a sops secret
        sops.secrets = mapAttrs' (name: peer: {
            name = "vpn/${name}";
            value = {
                path = "/etc/wireguard/${name}.conf";
            };
        }) cfg.peers;

        # For each peer, create a wg-quick interface
        networking.wireguard.interfaces = mapAttrs' (name: peer: {
            name = name;
            value = {
                enable = peer.enable;
                autostart = peer.autostart;
                configFile = config.sops.secrets."vpn/${name}".path;
            };
        }) cfg.peers;
    };
}