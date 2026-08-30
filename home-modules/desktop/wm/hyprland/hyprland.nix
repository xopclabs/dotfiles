{ inputs, pkgs, lib, config, ... }:

let
    cfg = config.modules.desktop.wm.hyprland;
    lock = "${pkgs.hyprlock}/bin/hyprlock";
    hardwareCfg = config.metadata.hardware;
    
    # Internal monitor reference
    internalMon = hardwareCfg.monitors.internal;
    monitor_internal = "desc:${internalMon.name}";
    
    # Helper to convert transform string to number for hyprland
    transformToNum = t: {
        "normal" = 0; "0" = 0;
        "90" = 1;
        "180" = 2;
        "270" = 3;
        "flipped" = 4;
        "flipped-90" = 5;
        "flipped-180" = 6;
        "flipped-270" = 7;
    }.${t} or 0;
    
    # Helper to format scale (avoid 1.000000, use 1 instead)
    formatScale = s: let
        str = toString s;
        # If it's a whole number like 1.000000, just use the integer part
    in if lib.hasSuffix ".000000" str 
       then lib.removeSuffix ".000000" str 
       else str;
    
    # Generate monitor rules from metadata
    # Format: NAME,RES@Hz,OFFSET,SCALE (no spaces after commas!)
    # Internal monitor
    internalMonitorRule = let
        transform = if internalMon ? transform then ",transform,${toString (transformToNum internalMon.transform)}" else "";
    in "desc:${internalMon.name},${internalMon.mode},${internalMon.position},${formatScale internalMon.scale}${transform}";
    
    # External monitors
    externalMonitorRules = lib.mapAttrsToList (key: ext: 
        "desc:${ext.name},${ext.mode},${ext.position},${formatScale ext.scale}"
    ) hardwareCfg.monitors.external;
    
    # All monitor rules including fallback for unknown monitors
    monitorRules = [ internalMonitorRule ] ++ externalMonitorRules ++ [
        # Fallback: enable any unknown monitor with preferred settings
        ",preferred,auto,1"
    ];
    
    # Generate workspace rules for all external monitors
    # Since only one external is connected at a time, rules for disconnected monitors are ignored
    externalWorkspaceRules = lib.flatten (lib.mapAttrsToList (key: ext: let
        monitor_desc = "desc:${ext.name}";
    in [
        "1, monitor:${monitor_desc}, default:true"
        "2, monitor:${monitor_desc}"
        "3, monitor:${monitor_desc}"
        "4, monitor:${monitor_desc}"
        "5, monitor:${monitor_desc}"
    ]) hardwareCfg.monitors.external);
    
    # Check if disableGapsOutOn matches any external monitor
    externalMonitorNames = lib.mapAttrsToList (k: v: v.name) hardwareCfg.monitors.external;
    disableGapsOnExternal = cfg.disableGapsOutOn != null && 
        lib.any (name: name == cfg.disableGapsOutOn) externalMonitorNames;
    
    cursorTheme = "OpenZone_Black";
    cursorSize = 24;

    internalTransform = transformToNum (
        if internalMon != null then (internalMon.transform or "0") else "0"
    );

    allMonitors =
        lib.optional (internalMon != null) internalMon
        ++ lib.attrValues hardwareCfg.monitors.external;

    # Per-panel digitizers from metadata (touch/tablet -> DRM connector).
    touchDeviceConfig = lib.concatMap (mon:
        let
            transform = toString (transformToNum (mon.transform or "0"));
        in map (devName: ''
            device {
              name=${devName}
              output=${mon.connector}
              transform=${transform}
            }
        '') mon.touch
    ) (lib.filter (m: m.touch != []) allMonitors);
in {
    options.modules.desktop.wm.hyprland = {
        enable = lib.mkEnableOption "hyprland";
        disableGapsOutOn = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Disable gaps_out (keep out zone) on specific monitor. If set, gaps_out will be 0 on this monitor.";
        };
        extraAutostart = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Extra commands to run on startup in exec-once.";
        };
        extraBinds = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Extra keybindings appended to hyprland settings.bind.";
        };
    };
    imports = [ ./scripts ];

    config = lib.mkIf cfg.enable {
        assertions = map (mon: {
            assertion = mon.connector != null;
            message = "metadata.hardware.monitors entry \"${mon.name}\" sets touch but has no connector (needed for Hyprland device output=).";
        }) (lib.filter (m: m.touch != []) allMonitors);

        home.packages = [
            pkgs.xwayland pkgs.wlsunset pkgs.wl-clipboard 
            pkgs.libinput pkgs.jq
            pkgs.playerctl
            pkgs.awww
        ];

        # Symlink wallpaper directory
        home.file.".config/wallpaper" = {
            recursive = true;
            source = ../wallpaper;
        };

        home.pointerCursor = {
            name = cursorTheme;
            package = pkgs.openzone-cursors;
            size = cursorSize;
            gtk.enable = true;
        };

        wayland.windowManager.hyprland = with config.colorScheme.palette; {
            enable = true;
            configType = "hyprlang";
            package = null;
            portalPackage = null;
            xwayland.enable = true;
            systemd.enable = false;
            settings = {
                "$terminal" = "${config.modules.terminals.default} -e tm";
                "$newterminal" = "${config.modules.terminals.default} -e tmux";
                "$mod" = "SUPER";
                "$altMod" = "SUPER_CTRL";

                # Monitor configuration from metadata
                monitor = monitorRules;

                exec-once = [
                    "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE"
                    "hyprctl setcursor ${cursorTheme} ${toString cursorSize}"
                ] ++ lib.optional (!config.modules.desktop.wm.wallpaperRotate.enable)
                    "awww-daemon && sleep 0.5 && awww img ~/.config/wallpaper/nord.png"
                ++ [
                    "hypr-windowrule"
                    "[workspace 8 silent] telegram-desktop"
                    "[workspace 9 silent] slack"
                ] ++ lib.optional config.modules.desktop.bars.waybar.enable "waybar"
                  ++ lib.optional config.modules.cli.tmux.enable "tmux new -s main"
                  ++ lib.optional config.modules.other.plover.enable "plover"
                  ++ [
                  ] ++ cfg.extraAutostart;

                input  = {
                    follow_mouse = true;
                    touchpad = {
                        natural_scroll = true;
                        scroll_factor = 0.5;
                    };
                    # Match internal panel rotation for tablets when present.
                    tablet = {
                        transform = internalTransform;
                    };
                    kb_layout = "us,ru";
                    kb_options = "grp:lalt_lshift_toggle,compose:ralt";
                };

                debug = {
                    disable_logs = false;
                };

                misc = {
                    disable_hyprland_logo = true;
                    disable_splash_rendering = true;
                    disable_autoreload = false;
                    enable_swallow = true;
                    enable_anr_dialog = false;
                    middle_click_paste = false;
                    swallow_regex = "kitty|tmux|(S|s)tremio|mpv";
                };

                general  = {
                    allow_tearing = true;
                    layout = "scrolling";
                    resize_on_border = true;
                    gaps_in = 6;
                    gaps_out = "0,0,0,12";
                    border_size = 4;
                    # "col.active_border" = lib.mkForce "0xff${base0D}";
                    # "col.inactive_border" = lib.mkForce "0xff${base01}";
                };

                env = [
                    "XCURSOR_THEME,${cursorTheme}"
                    "XCURSOR_SIZE,${toString cursorSize}"
                ];

                decoration = {
                    rounding = 0;
                    shadow.enabled = false;
                };

                animations  = {
                    enabled = true;
                    animation = [
                        "windows,1,2,default,slide"
                        "workspaces,1,3,default,slide"
                    ];
                };

                master = {
                    mfact = 0.6;
                };

                scrolling = {
                    fullscreen_on_one_column = true;
                    column_width = 0.495;
                    focus_fit_method = 1;
                    follow_focus = true;
                    follow_min_visible = 0.4;
                    explicit_column_widths = "0.333, 0.5, 0.667, 1.0";
                    wrap_focus = true;
                    wrap_swapcol = true;
                    direction = "right";
                };

                windowrule = [
                    # Fix telegram and slack (use direct id's because here we can't desc:*)
                    "workspace 8, monitor 0, match:class ^(telegram-desktop)$"
                    "workspace 9, monitor 0, match:class ^(slack)$"

                    # PiP are floating and pinned, resizing according to aspect ratio
                    "float on, match:title ^(Picture-in-Picture)$"
                    "pin on, match:title ^(Picture-in-Picture)$"
                    "keep_aspect_ratio on, match:title ^(Picture-in-Picture)$"

                    # Cursor modal windows are moved to the cursor
                    "move onscreen cursor -50% -50%, match:title ^(Cursor)$"

                    # Plover modal windows are floating and pinned
                    "float on, match:title ^(Plover: .*)$"
                    "pin on, match:title ^(Plover: .*)$"
                    "move onscreen cursor -50% -50%, match:title ^(Plover: .*)$"
                    # Paper Tape size
                    "min_size 250 400, match:title ^(Plover: Paper Tape)$"
                    "max_size 300 800, match:title ^(Plover: Paper Tape)$"
                    # Lookup
                    "min_size 300 300, match:title ^(Plover: Lookup)$"
                    "max_size 600 600, match:title ^(Plover: Lookup)$"

                    # Float telegram media viewer popups
                    "float on, match:class ^(org.telegram.desktop)$, match:title ^(Media viewer)$"
                    "keep_aspect_ratio on, match:class ^(org.telegram.desktop)$, match:title ^(Media viewer)$"
                    "size <80% <80%, match:class ^(org.telegram.desktop)$, match:title ^(Media viewer)$"

                    # Fix Sharing Indicator of firefox
                    "float on, match:title (.*)(Sharing Indicator)"
                    "move 50% 2%, match:title (.*)(Sharing Indicator)"
                    "no_shadow on, match:title (.*)(Sharing Indicator)"
                    "no_initial_focus on, match:title (.*)(Sharing Indicator)"

                    # flameshot
                    "suppress_event fullscreen, match:class ^(flameshot)$"
                    "float on, match:class ^(flameshot)$"
                    "monitor 1, match:class ^(flameshot)$"
                    "move 0 0, match:class ^(flameshot)$"
                    "no_anim on, match:class ^(flameshot)$"

                    # Malware aka zoom-us
                    "float on, match:title ^(as_toolbar)$"
                    "pin on, match:title ^(as_toolbar)$"
                    "float on, match:title ^(zoom_linux_float_video_window)$"
                    "pin on, match:title ^(zoom_linux_float_video_window)$"
                    "move onscreen cursor, match:class ^(zoom)$, match:title ^(menu window)$"
                    "move onscreen cursor, match:class ^(zoom)$, match:title ^(sub menu window)$"
                    "float on, match:class ^(zoom)$, match:title ^(annotate_toolbar)$"
                    "no_initial_focus on, match:class ^(zoom)$, match:title ^(annotate_toolbar)$"

                    # Zoom drawing overlay (covers the whole screen while annotating)
                    "float on, match:class ^(zoom)$, match:title ^(Annotation - Zoom)$"
                    "no_initial_focus on, match:class ^(zoom)$, match:title ^(Annotation - Zoom)$"
                    # No native pointer passthrough in Hyprland; no_focus is the closest we get
                    "no_focus on, match:class ^(zoom)$, match:title ^(Annotation - Zoom)$"

                    # No blur/borders on any zoom popup (drawing overlay, toolbars, camera/share panels)
                    "no_blur on, match:class ^(zoom)$"
                    "border_size 0, match:class ^(zoom)$"

                    # XWayland stuff
                    "opacity 0.0 override 0.0 override, match:class ^(xwaylandvideobridge)$"
                    "no_anim on, match:class ^(xwaylandvideobridge)$"
                    "no_initial_focus on, match:class ^(xwaylandvideobridge)$"
                    "max_size 1 1, match:class ^(xwaylandvideobridge)$"
                    "no_blur on, match:class ^(xwaylandvideobridge)$"
                    "immediate on, match:class ^(steam_app_38400)$"
                ];

                layerrule = [
                    "no_anim on, match:namespace waybar"
                    "no_anim on, match:namespace launcher"
                    "no_anim on, match:namespace selection"
                    # Launcher under waybar
                    "order -1, match:namespace launcher"
                ];
                workspace = externalWorkspaceRules ++ [
                    "6, monitor:${monitor_internal}, default:true"
                    "7, monitor:${monitor_internal}"
                    "8, monitor:${monitor_internal}"
                    "9, monitor:${monitor_internal}"
                    "10, monitor:${monitor_internal}"
                ]
                ++ (if cfg.disableGapsOutOn != null && cfg.disableGapsOutOn == hardwareCfg.monitors.internal.name then [
                    "6, gapsout:0"
                    "7, gapsout:0"
                    "8, gapsout:0"
                    "9, gapsout:0"
                    "10, gapsout:0"
                ] else if disableGapsOnExternal then [
                    "1, gapsout:0"
                    "2, gapsout:0"
                    "3, gapsout:0"
                    "4, gapsout:0"
                    "5, gapsout:0"
                ] else []);

                # binds
                bind = let
                    binding = mod: cmd: key: arg: "${mod}, ${key}, ${cmd}, ${arg}";
                    mvfocus = binding "$mod" "movefocus";
                    ws = binding "$mod" "workspace";
                    resizeactive = binding "$altMod" "resizeactive";
                    mvwindow = binding "$altMod" "movewindow";
                    mvtows = binding "$altMod" "movetoworkspace";
                    layoutmsg = binding "$mod" "layoutmsg";
                    shiftLayoutmsg = binding "$mod SHIFT" "layoutmsg";
                    workspaces = [
                        { key = "a"; n = "1"; } 
                        { key = "r"; n = "2"; }
                        { key = "s"; n = "3"; }
                        { key = "t"; n = "4"; }
                        { key = "g"; n = "5"; } 
                        { key = "q"; n = "6"; } 
                        { key = "w"; n = "7"; } 
                        { key = "f"; n = "8"; } 
                        { key = "p"; n = "9"; }
                        { key = "b"; n = "10"; }
                    ];
                in [
                    "CTRL SHIFT, B,  exec, pkill waybar; waybar"
                    "$mod, L, exec,  systemd-run --user $(${config.modules.desktop.launchers.default}-drun)"
                    ", Print, exec, screenshot"
                    "CTRL, Print, exec, annotate"
                    "CTRL SHIFT, Print, exec, screenrecord"
                    "$mod, Space, exec, $terminal"
                    "$altMod, Space, exec, $newterminal"
                    "$mod, H, exec, ${config.modules.browsers.default}"

                    "$mod, J, exec, eq-preset" 

                    "$mod, D, killactive"
                    "$mod, U, togglefloating"
                    "$mod, U, pin"
                    "$mod, Z, fullscreen"
                    "CTRL ALT, Delete, exit"

                    (mvfocus "n" "l")
                    (mvfocus "e" "d")
                    (mvfocus "i" "u")
                    (mvfocus "o" "r")
                    (mvwindow "n" "l")
                    (mvwindow "e" "d")
                    (mvwindow "i" "u")
                    (mvwindow "o" "r")
                    # layoutmsg focus wraps the tape instead of jumping monitors.
                    # Same keys as movefocus, so only one pair can be active.
                    # (layoutmsg "n" "focus l")
                    # (layoutmsg "e" "focus d")
                    # (layoutmsg "i" "focus u")
                    # (layoutmsg "o" "focus r")

                    # minus/equal are SYMB-only on Cradio; comma/period are on the base layer.
                    # (layoutmsg "minus" "colresize -conf")
                    # (layoutmsg "equal" "colresize +conf")
                    (layoutmsg "comma" "colresize -conf")
                    (layoutmsg "period" "colresize +conf")
                    # M is on the Colemak home row; Shift is the right thumb.
                    (layoutmsg "m" "consume_or_expel next")
                    (shiftLayoutmsg "m" "consume_or_expel prev")
                    (shiftLayoutmsg "comma" "swapcol l")
                    (shiftLayoutmsg "period" "swapcol r")
                ]
                ++ (map (w: ws w.key w.n) workspaces)
                ++ (map (w: mvtows w.key w.n) workspaces)
                ++ cfg.extraBinds;

                bindm = [
                    "$mod,mouse:272,movewindow"
                ];
                bindle = [
                    ",XF86MonBrightnessUp,   exec, brightnessctl s +5%"
                    ",XF86MonBrightnessDown, exec, brightnessctl s 5%-"
                    ",XF86KbdBrightnessUp,   exec, brightnessctl -d '*kbd*' s +1"
                    ",XF86KbdBrightnessDown, exec, brightnessctl -d '*kbd*' s 1-"
                    ",XF86AudioRaiseVolume,  exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
                    ",XF86AudioLowerVolume,  exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
                    ",XF86AudioPlay,         exec, playerctl play-pause"
                    ",XF86AudioPause,        exec, playerctl play-pause"
                    ",XF86AudioPlayPause,    exec, playerctl play-pause"
                ];

                bindl = [
                    ",switch:on:[Lid switch], exec, ${lock}"
                    ",switch:on:[Lid switch], exec, systemctl suspend"
                
                    # F13, F14 binds for keyboard layouts
                    ", XF86Tools, exec, hyprctl switchxkblayout sweep-keyboard 0"
                    ", XF86Tools, exec, hyprctl switchxkblayout zmk-project-sweep-keyboard 0"
                    ", XF86Launch5, exec, hyprctl switchxkblayout sweep-keyboard 1"
                    ", XF86Launch5, exec, hyprctl switchxkblayout zmk-project-sweep-keyboard 1"

                    ", XF86PowerOff, exec, systemctl suspend"
                ];

            };
            extraConfig = ''
                device {
                  name=kensington-expert-mouse
                  accel_profile=flat
                  sensitivity=-0.2
                }
                device {
                  name=nordic-2.4g-wireless-receiver-mouse
                  accel_profile=flat
                  sensitivity=-0.25
                  natural_scroll=true
                }
                device {
                  name=protoarc-em03-mouse
                  accel_profile=flat
                  sensitivity=-0.25
                  natural_scroll=true
                }

                # Digitizers from metadata.hardware.monitors.*.touch
                ${lib.concatStrings touchDeviceConfig}
              '';
        };
        # UWSM environment configuration for Hyprland
        xdg.configFile."uwsm/env".source = "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";

    };
}
