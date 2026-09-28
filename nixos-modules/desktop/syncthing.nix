{ config, lib, ... }:

with lib;
let
    cfg = config.desktop.syncthing;
in
{
    options.desktop.syncthing = {
        enable = mkEnableOption "Syncthing file synchronization";

        folders = mkOption {
            type = types.attrsOf (types.submodule {
                options = {
                    path = mkOption {
                        type = types.str;
                        description = "Local folder path";
                    };
                    label = mkOption {
                        type = types.str;
                        description = "Folder label";
                    };
                    type = mkOption {
                        type = types.enum [ "sendreceive" "sendonly" "receiveonly" ];
                        default = "sendreceive";
                        description = "Folder synchronization mode";
                    };
                    devices = mkOption {
                        type = types.listOf types.str;
                        default = [ ];
                        description = "Peer names from devices";
                    };
                };
            });
            default = { };
            description = "Folders to synchronize, keyed by Syncthing folder ID.";
        };

        devices = mkOption {
            type = types.attrsOf (types.submodule {
                options.id = mkOption {
                    type = types.str;
                    description = "Syncthing peer device ID.";
                };
            });
            default = { };
            description = "Remote Syncthing peers.";
        };
    };

    config = mkIf cfg.enable {
        services.syncthing = {
            enable = true;
            user = config.metadata.user;
            group = "users";
            dataDir = "/home/${config.metadata.user}/.local/state/syncthing";
            openDefaultPorts = true;
            settings = {
                inherit (cfg) devices folders;
            };
        };

        systemd.services.syncthing.unitConfig.RequiresMountsFor = mapAttrsToList (_: folder: folder.path) cfg.folders;
    };
}
