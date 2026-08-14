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
        networking.wg-quick.interfaces = mapAttrs' (name: peer: {
            name = name;
            value = {
                autostart = peer.autostart;
                configFile = config.sops.secrets."vpn/${name}".path;
            };
        }) cfg.peers;

        # wg-quick up is not idempotent: nixos-rebuild fails if the link is already up (manual start, leftover after a failed preStop, etc.).
        systemd.services = mapAttrs' (name: peer: {
            name = "wg-quick-${name}";
            value = {
                restartIfChanged = false;
                stopIfChanged = false;
                serviceConfig.ExecStartPre =
                    let
                        conf = config.sops.secrets."vpn/${name}".path;
                    in
                    [
                        (pkgs.writeShellScript "wg-quick-${name}-pre" ''
                            ${pkgs.wireguard-tools}/bin/wg-quick down ${conf} \
                                || ${pkgs.iproute2}/bin/ip link delete dev ${name} \
                                || true
                        '')
                    ];
            };
        }) (filterAttrs (_: peer: peer.autostart) cfg.peers);
    };
}