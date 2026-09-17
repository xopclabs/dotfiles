{ config, lib, pkgs, ... }:

let
    cfg = config.desktop.deckControllerPassthrough;
    usbip = config.boot.kernelPackages.usbip;
    command = pkgs.writeShellScriptBin "deck-controller-passthrough" ''
        set -eu
        case "''${1:-}" in
            start|stop|restart|status)
                exec ${pkgs.systemd}/bin/systemctl "$1" deck-controller-passthrough-${cfg.role}.service
                ;;
            *)
                echo "usage: deck-controller-passthrough {start|stop|restart|status}" >&2
                exit 2
                ;;
        esac
    '';
in
{
    options.desktop.deckControllerPassthrough = {
        enable = lib.mkEnableOption "Steam Deck controller passthrough over USB/IP";

        role = lib.mkOption {
            type = lib.types.enum [ "exporter" "importer" ];
            description = "Whether this host exports or imports the controller.";
        };

        device = {
            vendorId = lib.mkOption {
                type = lib.types.strMatching "[0-9a-fA-F]{4}";
                default = "28de";
                description = "USB vendor ID of the controller to forward.";
            };

            productId = lib.mkOption {
                type = lib.types.strMatching "[0-9a-fA-F]{4}";
                default = "1205";
                description = "USB product ID of the controller to forward.";
            };
        };

        exporter = {
            activateAtBoot = lib.mkEnableOption "controller export at boot";

            peerAddress = lib.mkOption {
                type = lib.types.nullOr (lib.types.strMatching "([0-9]{1,3}[.]){3}[0-9]{1,3}");
                default = null;
                description = "IPv4 address allowed to import and remotely control the controller.";
            };

            disconnectGraceSeconds = lib.mkOption {
                type = lib.types.ints.positive;
                default = 45;
                description = "Seconds without the importer before local controls are restored.";
            };

            remoteControl = {
                enable = lib.mkEnableOption "controlled SSH activation of the exporter";

                user = lib.mkOption {
                    type = lib.types.str;
                    default = "deck-controller";
                    description = "Dedicated SSH account used to control the exporter.";
                };

                authorizedKey = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "SSH public key allowed to start or stop the exporter.";
                };
            };

            reconnectTrigger = {
                enable = lib.mkEnableOption "a launcher that requests controller reconnection from the importer";

                user = lib.mkOption {
                    type = lib.types.str;
                    default = "deck-controller-reconnect";
                    description = "Restricted SSH account on the importer.";
                };

                identityFile = lib.mkOption {
                    type = lib.types.nullOr lib.types.path;
                    default = null;
                    description = "Private key used to request controller reconnection.";
                };

                hostPublicKey = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Expected importer SSH host public key, including its key type.";
                };
            };
        };

        importer = {
            exporterAddress = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Resolvable IPv4 address or hostname of the USB/IP exporter.";
            };

            remoteControl = {
                enable = lib.mkEnableOption "controlled SSH activation of the exporter";

                user = lib.mkOption {
                    type = lib.types.str;
                    default = "deck-controller";
                    description = "SSH account used to control the exporter.";
                };

                identityFile = lib.mkOption {
                    type = lib.types.nullOr lib.types.path;
                    default = null;
                    description = "Private key used to control the exporter.";
                };

                hostPublicKey = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Expected exporter SSH host public key, including its key type.";
                };
            };

            reconnectControl = {
                enable = lib.mkEnableOption "restricted SSH requests to reconnect the controller";

                user = lib.mkOption {
                    type = lib.types.str;
                    default = "deck-controller-reconnect";
                    description = "Dedicated SSH account used to request controller reconnection.";
                };

                authorizedKey = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "SSH public key allowed to request controller reconnection.";
                };
            };

            gamescopeLifecycle.enable = lib.mkEnableOption "controller forwarding around the Jovian Gamescope session";
        };
    };

    config = lib.mkIf cfg.enable (lib.mkMerge [
        {
            assertions = [
                {
                    assertion = cfg.role != "exporter" || cfg.exporter.peerAddress != null;
                    message = "The controller exporter requires exporter.peerAddress.";
                }
                {
                    assertion = cfg.role != "exporter" || !cfg.exporter.remoteControl.enable || cfg.exporter.remoteControl.authorizedKey != null;
                    message = "Remote exporter control requires exporter.remoteControl.authorizedKey.";
                }
                {
                    assertion = cfg.role != "exporter" || !cfg.exporter.reconnectTrigger.enable || (cfg.exporter.reconnectTrigger.identityFile != null && cfg.exporter.reconnectTrigger.hostPublicKey != null);
                    message = "The reconnect trigger requires exporter.reconnectTrigger.identityFile and hostPublicKey.";
                }
                {
                    assertion = cfg.role != "importer" || cfg.importer.exporterAddress != null;
                    message = "The controller importer requires importer.exporterAddress.";
                }
                {
                    assertion = cfg.role != "importer" || !cfg.importer.remoteControl.enable || (cfg.importer.remoteControl.identityFile != null && cfg.importer.remoteControl.hostPublicKey != null);
                    message = "Remote importer control requires importer.remoteControl.identityFile and hostPublicKey.";
                }
                {
                    assertion = cfg.role != "importer" || !cfg.importer.reconnectControl.enable || cfg.importer.reconnectControl.authorizedKey != null;
                    message = "Reconnect control requires importer.reconnectControl.authorizedKey.";
                }
                {
                    assertion = !cfg.importer.gamescopeLifecycle.enable || cfg.role == "importer";
                    message = "importer.gamescopeLifecycle is only valid for the importer role.";
                }
                {
                    assertion = !cfg.importer.gamescopeLifecycle.enable || cfg.importer.remoteControl.enable;
                    message = "Gamescope controller forwarding requires importer.remoteControl.";
                }
                {
                    assertion = !cfg.importer.gamescopeLifecycle.enable || (config.desktop.steam.enable && config.desktop.steam.jovian.enable);
                    message = "Gamescope controller forwarding requires desktop.steam with Jovian enabled.";
                }
            ];

            boot.kernelModules = lib.optional (cfg.role == "exporter") "usbip-host"
                ++ lib.optional (cfg.role == "importer") "vhci-hcd";
            environment.systemPackages = [ usbip command ];
        }

        (lib.mkIf (cfg.role == "exporter") (import ./exporter.nix {
            inherit config cfg lib pkgs usbip;
        }))
        (lib.mkIf (cfg.role == "importer") (import ./importer.nix {
            inherit config cfg lib pkgs usbip;
        }))
    ]);
}
