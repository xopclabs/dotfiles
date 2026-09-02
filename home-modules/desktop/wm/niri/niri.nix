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
    output_external = if firstExternal != null then niriOutputName firstExternal else output_internal;
    output_internal = if internalMon != null then niriOutputName internalMon else null;

    scratchPath = "${config.xdg.configHome}/niri/scratch.kdl";
    resetScratch = pkgs.writeShellScript "reset-niri-scratch" ''
        mkdir -p "$(dirname ${lib.escapeShellArg scratchPath})"
        cat > ${lib.escapeShellArg scratchPath} <<'EOF'
// Live niri overrides. Cleared on every home-manager switch.
EOF
    '';
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
                    default-column-width = {
                        proportion = 0.5;
                    };

                    gaps = 18;
                    struts = {
                        right = 64;
                        top = -18;
                        bottom = -18;
                    };

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

                binds = {
                    # Focus monitors
                    "Mod+A".action.focus-monitor-left = [];
                    "Mod+T".action.focus-monitor-right = [];
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

                    # Resizing windows
                    "Mod+WheelScrollUp".action.set-column-width = "+2.5%";
                    "Mod+WheelScrollDown".action.set-column-width = "-2.5%";
                    "Mod+P".action.switch-preset-column-width = [];

                    # Expand to edges
                    "Mod+X".action.maximize-window-to-edges = [];
                    # Zoom / Center
                    "Mod+Z".action.maximize-column = [];
                    "Mod+C".action.center-column = [];

                    # Close / float
                    "Mod+D".action.close-window = [];
                    "Mod+F".action.toggle-window-floating = [];

                    # Overview
                    "Mod+Q".action.toggle-overview = [];

                    # Terminal
                    "Mod+Space".action.spawn = [ config.modules.terminals.default "-e" "tm" ];
                    # Launcher
                    "Mod+L".action.spawn-sh = "systemd-run --user $(${config.modules.desktop.launchers.default}-drun)";
                    # Browser
                    "Mod+H".action.spawn = config.modules.browsers.default;

                    # Programs
                    "Print".action.spawn = "screenshot";
                    "Ctrl+Print".action.spawn = "annotate";
                    "Ctrl+Shift+Print".action.spawn = "screenrecord";
                    "Mod+J".action.spawn = "eq-preset";

                    # Auxiliary
                    "Ctrl+Alt+Delete".action.quit.skip-confirmation = true;
                    "Ctrl+Shift+B".action.spawn-sh = "pkill waybar; waybar";

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
                } // cfg.extraBinds;

                switch-events.lid-close.action.spawn = [ "systemctl" "suspend" ];

                input = {
                    focus-follows-mouse = { 
                        enable = true; 
                        max-scroll-amount = "25%";
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
                    { sh = "awww-daemon && sleep 0.5 && awww img ~/.config/wallpaper/nord.png"; }
                    { argv = [ "slack" ]; }
                    { argv = [ "telegram-desktop" ]; }
                ]
                ++ lib.optional config.modules.desktop.bars.waybar.enable { argv = [ "waybar" ]; }
                ++ lib.optional config.modules.cli.tmux.enable { argv = [ "tmux" "new" "-s" "main" ]; }
                ++ lib.optional config.modules.other.plover.enable { argv = [ "plover" ]; }
                ++ map (cmd: { sh = cmd; }) cfg.extraAutostart;

                outputs = lib.optionalAttrs (internalMon != null) {
                        ${output_internal} = mkOutput internalMon;
                    } // lib.mapAttrs' (_: ext: {
                        name = niriOutputName ext;
                        value = mkOutput ext;
                    }) hardwareCfg.monitors.external;

                workspaces = {
                    "messaging" = { name = "messaging"; open-on-output = output_internal; };
                };

                window-rules = [
                    {
                        matches = [ { app-id = "^org\\.telegram\\.desktop$"; at-startup = true; } ];
                        open-on-workspace = "messaging";
                    }
                    {
                        matches = [ { app-id = "^slack$"; at-startup = true; } ];
                        open-on-workspace = "messaging";
                    }

                    {
                        matches = [ { app-id = "^[Ss]team$"; at-startup = true; } ];
                        open-on-output = output_external;
                    }
                ];

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
