{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.modules.desktop.wm.gamma;

    outputSubmodule = types.submodule {
        options = {
            gamma = mkOption {
                type = types.nullOr types.float;
                default = null;
                description = "wl-gammactl-compatible gamma value for this output. Converted to wl-gammarelay-rs' inverse gamma convention internally.";
            };

            brightness = mkOption {
                type = types.nullOr types.float;
                default = null;
                description = "Software brightness value for this output.";
            };
        };
    };

    outputNames = attrNames cfg.outputs;
    dbusPath = output: "/outputs/${replaceStrings [ "-" ] [ "_" ] output}";

    setCommands = concatStringsSep "\n" (flatten (mapAttrsToList (output: settings:
        optional (settings.gamma != null) ''
            busctl --user set-property rs.wl-gammarelay ${dbusPath output} rs.wl.gammarelay Gamma d ${toString (1.0 / settings.gamma)} || true
        ''
        ++ optional (settings.brightness != null) ''
            busctl --user set-property rs.wl-gammarelay ${dbusPath output} rs.wl.gammarelay Brightness d ${toString settings.brightness} || true
        '') cfg.outputs));

    waitCondition = concatMapStringsSep " && " (output:
        ''busctl --user get-property rs.wl-gammarelay ${dbusPath output} rs.wl.gammarelay Gamma >/dev/null 2>&1''
    ) outputNames;

    package = pkgs.writeShellApplication {
        name = "display-gamma";
        runtimeInputs = [ cfg.package pkgs.coreutils pkgs.systemd ];
        text = ''
            set -u

            wl-gammarelay-rs run &
            relay_pid=$!

            for _ in $(seq 1 20); do
                if ${waitCondition}; then
                    break
                fi
                sleep 0.1
            done

            ${setCommands}

            wait "$relay_pid"
        '';
    };
in
{
    options.modules.desktop.wm.gamma = {
        enable = mkEnableOption "per-output Wayland gamma control via wl-gammarelay-rs";

        package = mkOption {
            type = types.package;
            default = pkgs.wl-gammarelay-rs;
            description = "wl-gammarelay-rs package to run.";
        };

        outputs = mkOption {
            type = types.attrsOf outputSubmodule;
            default = { };
            example = literalExpression ''
                {
                    "eDP-1" = {
                        gamma = 1.325;
                        brightness = 1.0;
                    };
                    "HDMI-A-1" = {
                        gamma = 1.1;
                    };
                }
            '';
            description = "Per-output gamma settings keyed by connector name, for example eDP-1 or HDMI-A-1.";
        };
    };

    config = mkIf cfg.enable {
        assertions = [
            {
                assertion = config.modules.desktop.wm.niri.enable || config.modules.desktop.wm.hyprland.enable;
                message = "modules.desktop.wm.gamma requires niri or Hyprland.";
            }
            {
                assertion = outputNames != [ ];
                message = "modules.desktop.wm.gamma.enable requires at least one configured output.";
            }
        ];

        home.packages = [ package ];
        modules.desktop.wm.niri.extraAutostart = mkIf config.modules.desktop.wm.niri.enable [ "display-gamma" ];
        modules.desktop.wm.hyprland.extraAutostart = mkIf config.modules.desktop.wm.hyprland.enable [ "display-gamma" ];
    };
}
