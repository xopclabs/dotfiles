{ inputs, pkgs, lib, config, ... }:

let
    cfg = config.modules.desktop.wm.niri;
    hardwareCfg = config.metadata.hardware;
    cursorTheme = "OpenZone_Black";
    cursorSize = 24;
in {
    options.modules.desktop.wm.niri = {
        enable = lib.mkEnableOption "niri";
        extraAutostart = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Extra commands to run on startup.";
        };
    };

    config = lib.mkIf cfg.enable {
        home.packages = [
            pkgs.xwayland pkgs.wl-clipboard pkgs.libinput pkgs.jq
        ];

        home.pointerCursor = {
            name = cursorTheme;
            package = pkgs.openzone-cursors;
            size = cursorSize;
            gtk.enable = true;
        };

        programs.niri = with config.colorScheme.palette; {
            enable = true;
            package = pkgs.niri;

            settings = {
                # Input configuration
                input = {
                    keyboard.xkb = {
                        layout = "us,ru";
                        options = "grp:lalt_lshift_toggle,compose:ralt";
                    };
                    touchpad = {
                        tap = true;
                        natural-scroll = true;
                        scroll-factor = 0.5;
                    };
                    tablet.map-to-output = lib.mkIf (hardwareCfg.monitors.internal != null) hardwareCfg.monitors.internal.name;
                };

                # Environment variables
                environment."NIXOS_OZONE_WL" = "1";
                environment."XCURSOR_THEME" = cursorTheme;
                environment."XCURSOR_SIZE" = toString cursorSize;
            };
        };
    };
}
