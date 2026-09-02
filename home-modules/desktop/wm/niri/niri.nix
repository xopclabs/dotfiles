{ inputs, pkgs, lib, config, ... }:

let
    cfg = config.modules.desktop.wm.niri;
    hardwareCfg = config.metadata.hardware;
    internalMon = hardwareCfg.monitors.internal;
    cursorTheme = "OpenZone_Black";
    cursorSize = 24;

    parseMode = modeStr: let
        atSplit = lib.splitString "@" modeStr;
        res = lib.splitString "x" (builtins.head atSplit);
        refreshStr = if builtins.length atSplit > 1 then lib.elemAt atSplit 1 else null;
    in {
        width = lib.toInt (lib.elemAt res 0);
        height = lib.toInt (lib.elemAt res 1);
    } // lib.optionalAttrs (refreshStr != null) {
        refresh = let
            n = builtins.fromJSON refreshStr;
        in if builtins.isInt n then n * 1.0 else n;
    };
    parsePosition = posStr: let
        xy = lib.splitString "x" posStr;
    in {
        x = lib.toInt (lib.elemAt xy 0);
        y = lib.toInt (lib.elemAt xy 1);
    };
    parseTransform = t: {
        flipped = lib.hasPrefix "flipped" t;
        rotation =
            if t == "normal" || t == "0" || t == "flipped" then 0
            else if t == "90" || t == "flipped-90" then 90
            else if t == "180" || t == "flipped-180" then 180
            else if t == "270" || t == "flipped-270" then 270
            else 0;
    };

    # niri matches outputs by connector (eDP-1) when set, else by description.
    niriOutputName = mon: if mon.connector != null then mon.connector else mon.name;
    mkOutput = mon: {
        mode = parseMode mon.mode;
        scale = mon.scale;
        transform = parseTransform (mon.transform or "normal");
        position = parsePosition mon.position;
    };
    firstExternal = let
        exts = lib.attrValues hardwareCfg.monitors.external;
    in if exts == [] then null else builtins.head exts;
    output_internal = if internalMon != null then niriOutputName internalMon else null;
    # Workspaces 1-5 on the first external; 6-10 on the internal panel.
    output_1_5 = if firstExternal != null then niriOutputName firstExternal else output_internal;
    output_6_10 = if output_internal != null then output_internal else output_1_5;
in {
    options.modules.desktop.wm.niri = {
        enable = lib.mkEnableOption "niri";
        extraAutostart = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Extra shell commands to spawn at niri startup.";
        };
        extraBinds = lib.mkOption {
            type = lib.types.attrs;
            default = {};
            description = "Extra niri keybindings merged into programs.niri.settings.binds.";
        };
    };
    imports = [ inputs.niri.homeModules.config ];

    config = lib.mkIf cfg.enable {
        home.packages = [
            pkgs.xwayland-satellite
            pkgs.wl-clipboard
            pkgs.libinput
            pkgs.jq
            pkgs.playerctl
            pkgs.awww
        ];

        programs.niri = with config.colorScheme.palette; {
            package = pkgs.niri;
            settings = {

                layout = {
                    gaps = 6;
                    struts = {
                        left = 12;
                        top = -6;
                        bottom = -6;
                    };
                    default-column-width.proportion = 0.5;

                    focus-ring.enable = false;

                    shadow.enable = false;

                    border = {
                        enable = true;
                        width = 4;
                        active.color = "#${base0D}";
                        inactive.color = "#${base01}";
                    };
                };

                spawn-at-startup = [
                    { sh = "awww-daemon && sleep 0.5 && awww img ~/.config/wallpaper/nord.png"; }
                    { argv = [ "telegram-desktop" ]; }
                    { argv = [ "slack" ]; }
                ]
                ++ lib.optional config.modules.desktop.bars.waybar.enable { argv = [ "waybar" ]; }
                ++ lib.optional config.modules.cli.tmux.enable { argv = [ "tmux" "new" "-s" "main" ]; }
                ++ lib.optional config.modules.other.plover.enable { argv = [ "plover" ]; }
                ++ map (cmd: { sh = cmd; }) cfg.extraAutostart;

                window-rules = [
                    {
                        open-maximized = false;
                        open-maximized-to-edges = false;
                    }
                    {
                        matches = [ { app-id = "^org\\.telegram\\.desktop$"; } ];
                        open-on-workspace = "8";
                    }
                    {
                        matches = [ { app-id = "^slack$"; } ];
                        open-on-workspace = "9";
                    }
                    {
                        matches = [ { app-id = "^[Ss]team$"; at-startup = true; } ];
                        open-on-workspace = "7";
                    }
                    {
                        matches = [ { title = "^Picture-in-Picture$"; } ];
                        open-floating = true;
                    }
                    {
                        matches = [ { title = "^Plover: .*"; } ];
                        open-floating = true;
                    }
                    {
                        matches = [ { title = "^Plover: Paper Tape$"; } ];
                        min-width = 250;
                        min-height = 400;
                        max-width = 300;
                        max-height = 800;
                    }
                    {
                        matches = [ { title = "^Plover: Lookup$"; } ];
                        min-width = 300;
                        min-height = 300;
                        max-width = 600;
                        max-height = 600;
                    }
                    {
                        matches = [ {
                            app-id = "^org\\.telegram\\.desktop$";
                            title = "^Media viewer$";
                        } ];
                        open-floating = true;
                        max-width = 1600;
                        max-height = 900;
                    }
                    {
                        matches = [ { title = "Sharing Indicator"; } ];
                        open-floating = true;
                        open-focused = false;
                    }
                    {
                        matches = [
                            { title = "^as_toolbar$"; }
                            { title = "^zoom_linux_float_video_window$"; }
                            { app-id = "^zoom$"; title = "^menu window$"; }
                            { app-id = "^zoom$"; title = "^sub menu window$"; }
                            { app-id = "^zoom$"; title = "^annotate_toolbar$"; }
                            { app-id = "^zoom$"; title = "^Annotation - Zoom$"; }
                        ];
                        open-floating = true;
                        open-focused = false;
                    }
                    {
                        matches = [ { app-id = "^zoom$"; } ];
                        border.enable = false;
                    }
                ];

                binds = {
                    "Ctrl+Shift+B".action.spawn-sh = "pkill waybar; waybar";

                    "Mod+L".action.spawn-sh = "systemd-run --user $(${config.modules.desktop.launchers.default}-drun)";

                    "Print".action.spawn = "screenshot";
                    "Ctrl+Print".action.spawn = "annotate";
                    "Ctrl+Shift+Print".action.spawn = "screenrecord";

                    "Mod+Space".action.spawn = [ config.modules.terminals.default "-e" "tm" ];
                    "Mod+Ctrl+Space".action.spawn = [ config.modules.terminals.default "-e" "tmux" ];

                    "Mod+H".action.spawn = config.modules.browsers.default;
                    "Mod+J".action.spawn = "eq-preset";

                    "Mod+D".action.close-window = [];
                    "Mod+U".action.toggle-window-floating = [];
                    "Mod+Z".action.fullscreen-window = [];
                    "Ctrl+Alt+Delete".action.quit.skip-confirmation = true;

                    "Mod+N".action.focus-column-left = [];
                    "Mod+E".action.focus-window-down = [];
                    "Mod+I".action.focus-window-up = [];
                    "Mod+O".action.focus-column-right = [];
                    "Mod+Ctrl+N".action.move-column-left = [];
                    "Mod+Ctrl+E".action.move-window-down = [];
                    "Mod+Ctrl+I".action.move-window-up = [];
                    "Mod+Ctrl+O".action.move-column-right = [];

                    "Mod+A".action.focus-workspace = "1";
                    "Mod+R".action.focus-workspace = "2";
                    "Mod+S".action.focus-workspace = "3";
                    "Mod+T".action.focus-workspace = "4";
                    "Mod+G".action.focus-workspace = "5";
                    "Mod+Q".action.focus-workspace = "6";
                    "Mod+W".action.focus-workspace = "7";
                    "Mod+F".action.focus-workspace = "8";
                    "Mod+P".action.focus-workspace = "9";
                    "Mod+B".action.focus-workspace = "10";
                    "Mod+Ctrl+A".action.move-column-to-workspace = "1";
                    "Mod+Ctrl+R".action.move-column-to-workspace = "2";
                    "Mod+Ctrl+S".action.move-column-to-workspace = "3";
                    "Mod+Ctrl+T".action.move-column-to-workspace = "4";
                    "Mod+Ctrl+G".action.move-column-to-workspace = "5";
                    "Mod+Ctrl+Q".action.move-column-to-workspace = "6";
                    "Mod+Ctrl+W".action.move-column-to-workspace = "7";
                    "Mod+Ctrl+F".action.move-column-to-workspace = "8";
                    "Mod+Ctrl+P".action.move-column-to-workspace = "9";
                    "Mod+Ctrl+B".action.move-column-to-workspace = "10";

                    "XF86MonBrightnessUp".action.spawn = [ "brightnessctl" "s" "+5%" ];
                    "XF86MonBrightnessDown".action.spawn = [ "brightnessctl" "s" "5%-" ];
                    "XF86KbdBrightnessUp".action.spawn = [ "brightnessctl" "-d" "*kbd*" "s" "+1" ];
                    "XF86KbdBrightnessDown".action.spawn = [ "brightnessctl" "-d" "*kbd*" "s" "1-" ];
                    "XF86AudioRaiseVolume" = {
                        allow-when-locked = true;
                        action.spawn = [ "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+" ];
                    };
                    "XF86AudioLowerVolume" = {
                        allow-when-locked = true;
                        action.spawn = [ "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-" ];
                    };
                    "XF86AudioPlay" = {
                        allow-when-locked = true;
                        action.spawn = [ "playerctl" "play-pause" ];
                    };
                    "XF86AudioPause" = {
                        allow-when-locked = true;
                        action.spawn = [ "playerctl" "play-pause" ];
                    };
                    "XF86Tools".action.switch-layout = "0";
                    "XF86Launch5".action.switch-layout = "1";
                    "XF86PowerOff".action.spawn = [ "systemctl" "suspend" ];
                } // cfg.extraBinds;

                switch-events.lid-close.action.spawn = [ "systemctl" "suspend" ];

                input = {
                    keyboard.xkb = {
                        layout = "us,ru";
                        options = "grp:lalt_lshift_toggle,compose:ralt";
                    };
                    touchpad = {
                        tap = true;
                        natural-scroll = false;
                        scroll-factor = 0.5;
                    };
                    mouse = {
                        accel-profile = "flat";
                        accel-speed = -0.25;
                        natural-scroll = true;
                    };
                    trackball = {
                        accel-profile = "flat";
                        accel-speed = -0.25;
                        natural-scroll = true;
                    };
                    focus-follows-mouse.enable = true;
                    tablet.map-to-output = lib.mkIf (output_internal != null) output_internal;
                    touch.map-to-output = lib.mkIf (output_internal != null) output_internal;
                };

                outputs = lib.optionalAttrs (internalMon != null) {
                        ${output_internal} = mkOutput internalMon;
                    } // lib.mapAttrs' (_: ext: {
                        name = niriOutputName ext;
                        value = mkOutput ext;
                    }) hardwareCfg.monitors.external;

                workspaces = {
                    "01" = { name = "1"; open-on-output = output_1_5; };
                    "02" = { name = "2"; open-on-output = output_1_5; };
                    "03" = { name = "3"; open-on-output = output_1_5; };
                    "04" = { name = "4"; open-on-output = output_1_5; };
                    "05" = { name = "5"; open-on-output = output_1_5; };
                    "06" = { name = "6"; open-on-output = output_6_10; };
                    "07" = { name = "7"; open-on-output = output_6_10; };
                    "08" = { name = "8"; open-on-output = output_6_10; };
                    "09" = { name = "9"; open-on-output = output_6_10; };
                    "10" = { name = "10"; open-on-output = output_6_10; };
                };

                cursor = {
                    theme = cursorTheme;
                    size = cursorSize;
                };

                environment = {
                    NIXOS_OZONE_WL = "1";
                    XCURSOR_THEME = cursorTheme;
                    XCURSOR_SIZE = toString cursorSize;
                };

                prefer-no-csd = true;
                hotkey-overlay.skip-at-startup = true;
                clipboard.disable-primary = true;
            };
        };
    };
}
