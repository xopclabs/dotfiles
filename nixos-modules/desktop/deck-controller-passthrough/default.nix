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
    };

    config = mkIf cfg.enable (mkMerge [
        {
            assertions = [
                {
                    assertion = cfg.role != "importer" || cfg.exporterAddress != null;
                    message = "desktop.deckControllerPassthrough.exporterAddress must be set for the importer role.";
                }
            ];

            boot.kernelModules = optional (cfg.role == "exporter") "usbip-host"
                ++ optional (cfg.role == "importer") "vhci-hcd";
            environment.systemPackages = [ usbip scripts.command ];
        }

        (mkIf (cfg.role == "exporter") (import ./exporter.nix { inherit cfg scripts usbip; }))
        (mkIf (cfg.role == "importer") (import ./importer.nix { inherit scripts; }))
    ]);
}
