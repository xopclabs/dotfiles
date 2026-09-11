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
    serviceName = output: "display-gamma-${output}.service";
    serviceNames = map serviceName outputNames;
    startService = "systemctl --user import-environment WAYLAND_DISPLAY NIRI_SOCKET HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP; systemctl --user reset-failed ${concatMapStringsSep " " escapeShellArg serviceNames}; systemctl --user restart ${concatMapStringsSep " " escapeShellArg serviceNames}";

    outputServices = mapAttrs' (output: settings: nameValuePair "display-gamma-${output}" {
        Unit = {
            Description = "Wayland gamma control for ${output}";
            PartOf = [ "graphical-session.target" ];
        };
        Service = {
            ExecStart = "${cfg.package}/bin/wl-gammactl -m ${output}${valueArg "-c" settings.contrast}${valueArg "-b" settings.brightness}${valueArg "-g" settings.gamma}";
            Restart = "on-failure";
            RestartSec = 1;
        };
    }) cfg.outputs;
in
{
    options.modules.desktop.wm.gamma = {
        enable = mkEnableOption "per-output Wayland contrast/brightness/gamma control via wl-gammactl";

        package = mkOption {
            type = types.package;
            default = wlGammactl;
            description = "wl-gammactl package to run.";
        };

        outputs = mkOption {
            type = types.attrsOf outputSubmodule;
            default = { };
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

        home.packages = [ cfg.package ];

        systemd.user.services = outputServices;

        modules.desktop.wm.niri.extraAutostart = mkIf config.modules.desktop.wm.niri.enable [ startService ];
        modules.desktop.wm.hyprland.extraAutostart = mkIf config.modules.desktop.wm.hyprland.enable [ startService ];
    };
}
