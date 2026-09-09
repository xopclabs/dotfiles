{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.modules.desktop.wm.gamma;

    wlGammactl = pkgs.wl-gammactl.overrideAttrs (old: {
        src = pkgs.fetchFromGitHub {
            owner = "JohnMertz";
            repo = "wl-gammactl";
            rev = "3bc04ba0135b647b9d763415d3f8af60b40d34fd";
            hash = "sha256-+o6brJXz9BQUyMmadEnR1pd1KMUHYd/VSmKBJH0Q1H0=";
        };

        patches = [ ../../../patches/wl-gammactl/per-output-exclusive.patch ];

        postPatch = (old.postPatch or "") + ''
            substituteInPlace meson.build \
                --replace-fail "dep_wlroots = dependency('wlroots-0.20')" "" \
                --replace-fail "dep_wlroots," ""
        '';
    });

    outputSubmodule = types.submodule {
        options = {
            contrast = mkOption {
                type = types.nullOr types.float;
                default = null;
                description = "Contrast value for this output.";
            };

            brightness = mkOption {
                type = types.nullOr types.float;
                default = null;
                description = "Software brightness value for this output.";
            };

            gamma = mkOption {
                type = types.nullOr types.float;
                default = null;
                description = "Gamma value for this output.";
            };
        };
    };

    outputNames = attrNames cfg.outputs;

    valueArg = flag: value: optionalString (value != null) " ${flag} ${toString value}";
    configuredOutputArms = concatStringsSep "\n" (mapAttrsToList (output: settings: ''
        ${escapeShellArg output})
            wl-gammactl -m "$output"${valueArg "-c" settings.contrast}${valueArg "-b" settings.brightness}${valueArg "-g" settings.gamma} &
            pids="$pids $!"
            ;;
    '') cfg.outputs);

    fallbackOutputArm = ''
        *)
            ;;
    '';

    startService = "systemctl --user import-environment WAYLAND_DISPLAY NIRI_SOCKET HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP; systemctl --user reset-failed display-gamma.service; systemctl --user restart display-gamma.service";

    package = pkgs.writeShellApplication {
        name = "display-gamma";
        runtimeInputs = [ cfg.package pkgs.coreutils pkgs.jq pkgs.systemd ]
            ++ optional config.modules.desktop.wm.niri.enable pkgs.niri
            ++ optional config.modules.desktop.wm.hyprland.enable pkgs.hyprland;
        text = ''
            set -u

            pids=""

            current_outputs() {
                if [ -n "''${NIRI_SOCKET:-}" ]; then
                    niri msg --json outputs | jq -r 'keys[]'
                elif [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
                    hyprctl monitors -j | jq -r '.[].name'
                else
                    return 1
                fi
            }

            stop_clients() {
                for pid in $pids; do
                    kill "$pid" 2>/dev/null || true
                done
                pids=""
            }

            cleanup() {
                stop_clients
            }

            start_output() {
                output=$1
                case "$output" in
                    ${configuredOutputArms}
                    ${fallbackOutputArm}
                esac
            }

            start_clients() {
                stop_clients
                while IFS= read -r output; do
                    start_output "$output"
                done < <(current_outputs)
            }

            trap cleanup EXIT INT TERM

            start_clients

            while IFS= read -r line; do
                case "$line" in
                    ACTION=change|HOTPLUG=1)
                        sleep ${toString cfg.hotplugDebounceSec}
                        start_clients
                        ;;
                esac
            done < <(udevadm monitor --subsystem-match=drm --property 2>/dev/null)
        '';
    };
in
{
    options.modules.desktop.wm.gamma = {
        enable = mkEnableOption "per-output Wayland contrast/brightness/gamma control via wl-gammactl";

        package = mkOption {
            type = types.package;
            default = wlGammactl;
            description = "wl-gammactl package to run.";
        };

        hotplugDebounceSec = mkOption {
            type = types.float;
            default = 0.5;
            description = "Seconds to wait after a DRM hotplug event before re-applying configured values.";
        };

        outputs = mkOption {
            type = types.attrsOf outputSubmodule;
            default = { };
            example = literalExpression ''
                {
                    "eDP-1" = {
                        contrast = 0.975;
                        brightness = 1.0;
                        gamma = 1.25;
                    };
                    "HDMI-A-1" = {
                        gamma = 1.1;
                    };
                }
            '';
            description = "Per-output settings keyed by connector name, for example eDP-1 or HDMI-A-1.";
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

        home.packages = [
            cfg.package
            package
        ];

        systemd.user.services.display-gamma = {
            Unit = {
                Description = "Per-output Wayland gamma control";
                PartOf = [ "graphical-session.target" ];
            };
            Service = {
                ExecStartPre = "${pkgs.runtimeShell} -c '${pkgs.procps}/bin/pkill -x wl-gammactl || true'";
                ExecStart = "${package}/bin/display-gamma";
                Restart = "on-failure";
                RestartSec = 1;
            };
        };

        modules.desktop.wm.niri.extraAutostart = mkIf config.modules.desktop.wm.niri.enable [ startService ];
        modules.desktop.wm.hyprland.extraAutostart = mkIf config.modules.desktop.wm.hyprland.enable [ startService ];
    };
}
