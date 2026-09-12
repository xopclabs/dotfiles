{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.desktop.deckControllerPassthrough;
    usbip = config.boot.kernelPackages.usbip;
    scripts = import ./scripts.nix { inherit cfg pkgs usbip; };
in
{
    options.desktop.deckControllerPassthrough = {
        enable = mkEnableOption "Steam Deck controller passthrough over USB/IP";

        role = mkOption {
            type = types.enum [ "exporter" "importer" ];
            description = "Whether this host exports the physical Deck controller or imports it.";
        };

        exporterAddress = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Resolvable IPv4 address or hostname of the USB/IP exporter.";
        };

        vendorId = mkOption {
            type = types.strMatching "[0-9a-fA-F]{4}";
            default = "28de";
            description = "USB vendor ID of the controller to forward.";
        };

        productId = mkOption {
            type = types.strMatching "[0-9a-fA-F]{4}";
            default = "1205";
            description = "USB product ID of the controller to forward.";
        };

        bootActivation = mkOption {
            type = types.bool;
            default = false;
            description = "Start the exporter automatically after the network is online.";
        };

        allowedPeerAddress = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "IPv4 address allowed to control the exporter and observed by its disconnect watchdog.";
        };

        disconnectGraceSeconds = mkOption {
            type = types.ints.positive;
            default = 45;
            description = "How long an observed USB/IP peer may be absent before the exporter restores local controls.";
        };

        remoteControl = {
            enable = mkEnableOption "controlled SSH activation of the exporter";

            user = mkOption {
                type = types.str;
                default = "deck-controller";
                description = "Dedicated SSH account used by the importer to start or stop forwarding.";
            };

            authorizedKey = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "SSH public key permitted to issue the forced start or stop command on the exporter.";
            };

            identityFile = mkOption {
                type = types.nullOr types.path;
                default = null;
                description = "Private key path used by the importer for controlled SSH activation.";
            };

            hostPublicKey = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Expected exporter SSH host public key, including its key type.";
            };
        };

        gamescopeLifecycle = mkEnableOption "controller forwarding around the Jovian Gamescope session";
    };

    config = mkIf cfg.enable (mkMerge [
        {
            assertions = [
                {
                    assertion = cfg.role != "importer" || cfg.exporterAddress != null;
                    message = "desktop.deckControllerPassthrough.exporterAddress must be set for the importer role.";
                }
                {
                    assertion = !cfg.bootActivation || cfg.role == "exporter";
                    message = "desktop.deckControllerPassthrough.bootActivation is only valid for the exporter role.";
                }
                {
                    assertion = !cfg.gamescopeLifecycle || cfg.role == "importer";
                    message = "desktop.deckControllerPassthrough.gamescopeLifecycle is only valid for the importer role.";
                }
                {
                    assertion = cfg.role != "exporter" || !cfg.remoteControl.enable || (cfg.allowedPeerAddress != null && cfg.remoteControl.authorizedKey != null);
                    message = "Controlled exporter activation requires allowedPeerAddress and remoteControl.authorizedKey.";
                }
                {
                    assertion = !cfg.gamescopeLifecycle || (cfg.remoteControl.enable && cfg.remoteControl.identityFile != null && cfg.remoteControl.hostPublicKey != null);
                    message = "Gamescope controller forwarding requires remoteControl plus identityFile and hostPublicKey on the importer.";
                }
            ];

            boot.kernelModules = optional (cfg.role == "exporter") "usbip-host"
                ++ optional (cfg.role == "importer") "vhci-hcd";
            environment.systemPackages = [ usbip scripts.command ];
        }

        (mkIf (cfg.role == "exporter") (import ./exporter.nix { inherit cfg scripts usbip lib; }))
        (mkIf (cfg.role == "importer") (import ./importer.nix { inherit cfg scripts lib; }))
    ]);
}
