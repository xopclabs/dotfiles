{ inputs, pkgs, lib, config, ... }:

let
    cfg = config.modules.desktop.wm.niri;
    hardwareCfg = config.metadata.hardware;
    monitors = hardwareCfg.monitors;
    internalMonitors = lib.filter (mon: mon.internal) (lib.attrValues monitors);
    externalMonitors = lib.filter (mon: !mon.internal) (lib.attrValues monitors);
    internalMon = if internalMonitors == [] then null else builtins.head internalMonitors;
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

    primaryConnector = mon: if mon.connectors != [] then builtins.head mon.connectors else null;
    niriOutputName = mon: if mon.name != "" then mon.name else primaryConnector mon;
    # Niri output configuration keys should be stable monitor descriptions, not
    # ephemeral DRM connector names like DP-1/DP-2. Keep connector names in
    # metadata for Hyprland/scripts, but don't generate Niri output blocks for
    # them when a description is known.
    niriOutputTargets = mon: [ (niriOutputName mon) ];
    mkOutput = mon: {
        mode = parseMode mon.mode;
        scale = mon.scale;
        transform = parseTransform (mon.transform or "normal");
        variable-refresh-rate = mon.variableRefreshRate;
    } // lib.optionalAttrs (!config.modules.desktop.wm.monitorPlacement.enable && mon.position != null) {
        position = parsePosition mon.position;
    };
    mkOutputAttrs = mon: lib.genAttrs (niriOutputTargets mon) (_: mkOutput mon);
    firstExternal = if externalMonitors == [] then null else builtins.head externalMonitors;
    output_external = if firstExternal != null then niriOutputName firstExternal else output_internal;
    output_internal = if internalMon != null then niriOutputName internalMon else null;

    scratchPath = "${config.xdg.configHome}/niri/scratch.kdl";
    scripts = import ./scripts { inherit pkgs lib config; };
    inherit (scripts) focusOutput autoPlaceOutputs placeOutputs resetScratch;
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
        ] ++ scripts.packages;

        programs.niri = with config.colorScheme.palette; {
            package = pkgs.niri;
            settings = {
                layout = {
                    default-column-width = {
                        proportion = 0.5;
                    };

                    preset-column-widths = [
                        { proportion = 0.65; }
                        { proportion = 0.33; }
                        { proportion = 0.85; }
                        { proportion = 0.20; }
                    ];

                    gaps = 16;
                    struts = {
                        left = 24;
                        right = 24;
                        top = -16;
                        bottom = -16;
                    };
                    always-center-single-column = true;

                    border = {
                        enable = true;
                        width = 4;
                        active.color = "#${base0D}";
                        inactive.color = "#${base01}";
                        urgent.color = "#${base08}";
                    };
                    focus-ring.enable = false;

                    insert-hint = {
                        enable = true;
                        display.color ="#${base0D}80";
                    };

                    shadow.enable = false;
                };

                overview = {
                    zoom = 0.35;
                };

                layer-rules = [
                    {
                        matches = [ { namespace = "^awww-daemon_backdrop$"; }
                        ];
                        place-within-backdrop = true;
                    }
                    {
                        matches = [ { namespace = "^notifications$"; } ];
                        block-out-from = "screencast";
                    }
                ] ++ lib.optionals config.modules.desktop.shells.noctalia.enable [
                    {
                        matches = [ { namespace = "^noctalia-(bar-[^\"]+|notification|dock|panel|attached-panel|osd)$"; } ];
                        background-effect = {
                            xray = false;
                        };
                    }
                    {
                        matches = [ { namespace = "^noctalia-window-switcher$"; } ];
                        background-effect = {
                            blur = true;
                            xray = false;
                        };
                    }
                ];

                binds = {
                    # Focus a monitor, or cycle its non-empty workspaces if already focused
                    "Mod+A" = if firstExternal != null then {
                        action.spawn = [ (lib.getExe focusOutput) ] ++ niriOutputTargets firstExternal;
                    } else {
                        action.focus-monitor-left = [];
                    };
                    "Mod+T" = if internalMon != null then {
                        action.spawn = [ (lib.getExe focusOutput) ] ++ niriOutputTargets internalMon;
                    } else {
                        action.focus-monitor-right = [];
                    };
                    # Move columns to monitors
                    "Mod+Ctrl+A".action.move-column-to-monitor-left = [];
                    "Mod+Ctrl+T".action.move-column-to-monitor-right = [];

                    # Focus workspaces
                    "Mod+R".action.focus-workspace-down = [];
                    "Mod+S".action.focus-workspace-up = [];
                    # Move columns to workspaces
                    "Mod+Ctrl+R".action.move-column-to-workspace-down = [];
                    "Mod+Ctrl+S".action.move-column-to-workspace-up = [];

                    # Focus columns or windows
                    "Mod+N".action.focus-column-or-monitor-left = [];
                    "Mod+E".action.focus-window-or-monitor-down = [];
                    "Mod+I".action.focus-window-or-monitor-up = [];
                    "Mod+O".action.focus-column-or-monitor-right = [];
                    # Move columns or windows (prohibit moving to other monitors)
                    "Mod+Ctrl+N".action.move-column-left = [];
                    "Mod+Ctrl+E".action.move-window-down = [];
                    "Mod+Ctrl+I".action.move-window-up = [];
                    "Mod+Ctrl+O".action.move-column-right = [];

                    # Scroll wheel focusing
                    "Mod+WheelScrollUp" = { cooldown-ms=50; action.focus-column-right = []; };
                    "Mod+WheelScrollDown" = { cooldown-ms=50; action.focus-column-left = []; };
                    "Mod+Alt+WheelScrollUp" = { cooldown-ms=75; action.focus-workspace-up = []; };
                    "Mod+Alt+WheelScrollDown" = { cooldown-ms=75; action.focus-workspace-down = []; };

                    # Resizing windows
                    "Mod+Ctrl+WheelScrollUp".action.set-column-width = "+2.5%";
                    "Mod+Ctrl+WheelScrollDown".action.set-column-width = "-2.5%";
                    "Mod+P".action.switch-preset-column-width = [];

                    # Zoom on the window
                    "Mod+Z".action.maximize-window-to-edges = [];
                    # Expand / center
                    "Mod+X".action.maximize-column = [];
                    "Mod+C".action.center-column = [];

                    # Close / float
                    "Mod+D".action.close-window = [];
                    "Mod+F".action.toggle-window-floating = [];

                    # Tabbing 
                    "Mod+Q".action.toggle-column-tabbed-display = [];
                    "Mod+W".action.consume-or-expel-window-left = [];

                    # Overview
                    "Mod+Tab".action.toggle-overview = [];

                    # Terminal
                    "Mod+Space".action.spawn = [ config.modules.terminals.default "-e" "tm" "-w" "-n" ];
                    "Mod+Ctrl+Space".action.spawn = [ config.modules.terminals.default "-e" "tmux" ];
                    # Launcher
                    "Mod+L".action.spawn = "launcher-drun";
                    # Browser
                    "Mod+H".action.spawn = config.modules.browsers.default;

                    # Programs
                    "Print".action.spawn = "screenshot";
                    "Ctrl+Print".action.spawn = "annotate";
                    "Ctrl+Shift+Print".action.spawn = "screenrecord";
                    "Mod+J".action.spawn = "eq-preset";

                    # Dynamic screencast
                    "Mod+Alt+B".action.set-dynamic-cast-monitor = [];
                    "Mod+Ctrl+B".action.set-dynamic-cast-window = [];
                    "Mod+Alt+C".action.clear-dynamic-cast-target = [];

                    # Auxiliary
                    "Ctrl+Alt+Delete".action.quit.skip-confirmation = true;
                    "Ctrl+Shift+B".action.spawn = "bar-restart";

                    # Media
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
                } // lib.optionalAttrs config.modules.desktop.shells.noctalia.enable {
                    "Mod+Comma".action.spawn-sh = "noctalia msg settings-toggle";
                    "XF86MonBrightnessUp" = {
                        allow-when-locked = true;
                        action.spawn = [ "noctalia" "msg" "brightness-up" "5%" ];
                    };
                    "XF86MonBrightnessDown" = {
                        allow-when-locked = true;
                        action.spawn = [ "noctalia" "msg" "brightness-down" "5%" ];
                    };
                } // cfg.extraBinds;

                switch-events.lid-close.action.spawn = [ "systemctl" "suspend" ];

                input = {
                    focus-follows-mouse = { 
                        enable = true; 
                        max-scroll-amount = "10%";
                    };

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

                    tablet.map-to-output = lib.mkIf (output_internal != null) output_internal;
                    touch.map-to-output = lib.mkIf (output_internal != null) output_internal;
                };

                spawn-at-startup = [
                    { sh = "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP NIRI_SOCKET && systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP NIRI_SOCKET && systemctl --user start nixos-fake-graphical-session.target"; }
                ]
                ++ lib.optional (placeOutputs != null) { argv = [ (lib.getExe placeOutputs) "--watch" ]; }
                ++ lib.optional (!config.modules.desktop.wm.wallpaperRotate.enable)
                    { sh = "awww-daemon && sleep 0.5 && awww img ~/.config/wallpaper/nord.png"; }
                ++ [
                    { argv = [ "slack" ]; }
                    { argv = [ "Telegram" ]; }
                ]
                ++ lib.optional config.modules.desktop.bars.waybar.enable { argv = [ "waybar" ]; }
                ++ lib.optional config.modules.desktop.shells.noctalia.enable { argv = [ "noctalia" ]; }
                ++ lib.optional config.modules.cli.tmux.enable { argv = [ "tmux" "new" "-s" "main" ]; }
                ++ lib.optional config.modules.other.plover.enable { argv = [ "plover" ]; }
                ++ map (cmd: { sh = cmd; }) cfg.extraAutostart;

                outputs = lib.optionalAttrs (internalMon != null) {
                        ${output_internal} = mkOutput internalMon;
                    }
                    // lib.foldl' (acc: ext: acc // mkOutputAttrs ext) {} externalMonitors;

                workspaces = {
                    "messaging" = { name = "messaging"; open-on-output = output_internal; };
                };

                window-rules = [
                    # Window size preferences
                    # Noctalia settings
                    {
                        matches = [ { app-id = "^(dev\\.noctalia\\.Noctalia|noctalia-settings)$"; } ];
                        open-floating = true;
                        default-column-width = { fixed = 1080; };
                        default-window-height = { fixed = 920; };
                    }
                    # Maximized windows
                    {
                        matches = [ 
                            { app-id = "^[Ss]lack$"; } 
                            { app-id = "^[Ss]team$"; } 
                            { app-id = "^[Cc]ursor$";}
                            { app-id = "^[Ff]irefox$"; } 
                        ];
                        open-maximized = true;
                    }
                    # Bigger windows
                    {
                        matches = [ 
                            { app-id = "^(org\\.telegram\\.desktop|Telegram)$"; } 
                            { app-id = "^(zoom|Zoom|us\\.zoom\\.Zoom)$"; title = "Zoom Workplace - .+"; } 
                        ];
                        default-column-width = { proportion = 0.75; };
                    }

                    # Workspace pinning
                    {
                        matches = [ 
                            { app-id = "^(org\\.telegram\\.desktop|Telegram)$"; at-startup = true; } 
                            { app-id = "^[Ss]lack$"; at-startup = true; } 
                        ];
                        open-on-workspace = "messaging";
                        open-focused = false;
                    }
                    {
                        matches = [ { app-id = "^[Ss]team$"; at-startup = true; } ];
                        open-on-output = output_external;
                    }

                    # Worst software on Earth's rules
                    # Catch-all rule to float all Zoom windows, to override downstream
                    {
                        matches = [ { app-id = "^(zoom|Zoom|us\\.zoom\\.Zoom)$"; } ];
                        excludes = [
                            { title = "^Zoom Workplace - "; }
                            { title = "^Meeting$"; }
                            { title = "^Meeting chat$"; }
                            { title = "^(.+)'s Zoom Meeting$"; }
                        ];
                        open-floating = true;
                        open-focused = false;
                    }
                    # Do not float workspace, meeting and chat
                    {
                        matches = [
                            { app-id = "^(zoom|Zoom|us\\.zoom\\.Zoom)$"; title = "^Meeting$"; }
                            { app-id = "^(zoom|Zoom|us\\.zoom\\.Zoom)$"; title = "^Meeting chat$"; }
                            { app-id = "^(zoom|Zoom|us\\.zoom\\.Zoom)$"; title = "^Zoom Workplace - "; }
                        ];
                        open-floating = false;
                    }
                    # Pre-join mic/camera dialog is special and needs manual placing
                    {
                        matches = [ { app-id = "^(zoom|Zoom|us\\.zoom\\.Zoom)$"; title = "^(.+)'s Zoom Meeting$"; } ];
                        open-floating = true;
                        open-focused = true;
                        default-floating-position = {
                            x = 0;
                            y = 100;
                            relative-to = "top";
                        };
                    }
                    # Toolbars/popups are at the top
                    {
                        matches = [ { app-id = "^(zoom|Zoom|us\\.zoom\\.Zoom)$"; title = "^(as_toolbar|annotate_toolbar|as_preview)$"; } ];
                        open-floating = true;
                        open-focused = false;
                        default-column-width = {};
                        default-window-height = { fixed = 86; };
                        default-floating-position = {
                            x = 0;
                            y = 0;
                            relative-to = "top";
                        };
                        border.enable = false;
                    }

                    # Screencast block-outs
                    {
                        matches = [
                            { app-id = "^(org\\.telegram\\.desktop|Telegram)$"; }
                            { app-id = "^[Ss]team$"; }
                        ];
                        block-out-from = "screencast";
                    }
                    {
                        matches = [
                            {
                                app-id = "^[Ff]irefox$";
                                title = "(?i)(gmail|youtube|bitwarden|reddit)";
                            }
                        ];
                        block-out-from = "screencast";
                    }

                    # Screencast indicator style
                    {
                        matches = [ { is-window-cast-target = true; } ];
                        border = {
                            active.color = "#${base08}";
                            inactive.color = "#${base08}80";
                        };
                        tab-indicator = {
                            active.color = "#${base08}";
                            inactive.color = "#${base08}80";
                        };
                    }
                ];

                cursor = {
                    theme = cursorTheme;
                    size = cursorSize;
                };

                debug = lib.optionalAttrs config.modules.desktop.shells.noctalia.enable {
                    honor-xdg-activation-with-invalid-serial = [];
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

        # Scratch must be included last, but it's not possible with current niri-flake, so we're writing the config file manually.
        xdg.configFile.niri-config.source = lib.mkForce (pkgs.writeText "niri-config.kdl" (
            config.programs.niri.finalConfig
            + "\ninclude \"${scratchPath}\"\n"
        ));

        # Mutable overlay sourced last; activation truncates it on every switch.
        home.activation.niriScratch =
            lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
                run ${resetScratch}
            '';
    };
}
