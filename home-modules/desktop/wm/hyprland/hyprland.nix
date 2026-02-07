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
    };
    imports = [ ./scripts ];

    config = lib.mkIf cfg.enable {
        
        home.packages = [
            pkgs.xwayland pkgs.wlsunset pkgs.wl-clipboard 
            pkgs.libinput pkgs.jq
            pkgs.playerctl
            pkgs.swww
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
            package = null;
            portalPackage = null;
            xwayland.enable = true;
            systemd = {
                enable = true;
                variables = ["--all"];  # Export all variables to systemd
            };

            settings = {
                "$terminal" = "${config.modules.terminals.default} -e tm";
                "$newterminal" = "${config.modules.terminals.default} -e tmux";
                "$mod" = "SUPER";
                "$altMod" = "SUPER_CTRL";

                # Monitor configuration from metadata
                monitor = monitorRules;

                exec-once = [
                    "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
                    "hyprctl setcursor ${cursorTheme} ${toString cursorSize}"
                    "swww-daemon && sleep 0.5 && swww img ~/.config/wallpaper/nord.png"
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
                    tablet = {
                        transform = 2;
                    };
                    kb_layout = "us,ru";
                    kb_options = "grp:lalt_lshift_toggle,compose:ralt";
                };

                misc = {
                    disable_hyprland_logo = true;
                    disable_autoreload = false;
                    enable_swallow = true;
                    enable_anr_dialog = false;
                    middle_click_paste = false;
                    swallow_regex = "kitty|tmux|(S|s)tremio|mpv";
                };

                general  = {
                    allow_tearing = true;
                    layout = "master";
                    resize_on_border = true;
                    gaps_in = 9;
                    gaps_out = "0,0,0,18";
                    border_size = 4;
                    # "col.active_border" = lib.mkForce "0xff${base0D}";
                    # "col.inactive_border" = lib.mkForce "0xff${base01}";
                };

                env = [
                    "WLR_DRM_NO_ATOMIC,1"
                    "XCURSOR_THEME,${cursorTheme}"
                    "XCURSOR_SIZE,${toString cursorSize}"
                ];

                decoration = {
                    rounding = 0;
                    shadow = {
                        enabled = true;
                        range = 30;
                        color = lib.mkForce "0x8800000";
                    };
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

                windowrulev2 = [
                    # Fix telegram and slack (use direct id's because here we can't desc:*)
                    "workspace 8, monitor 0, class:^(telegram-desktop)$"
                    "workspace 9, monitor 0, class:^(slack)$"

                    # PiP are floating and pinned, resizing according to aspect ratio
                    "float, title:^(Picture-in-Picture)$"
                    "pin, title:^(Picture-in-Picture)$" 
                    "keepaspectratio, title:^(Picture-in-Picture)$" 

                    # Cursor modal windows are moved to the cursor
                    "move onscreen cursor -50% -50%, title:^(Cursor)$"

                    # Plover modal windows are floating and pinned
                    "float, title:^(Plover: .*)$"
                    "pin, title:^(Plover: .*)$" 
                    "move onscreen cursor -50% -50%, title:^(Plover: .*)$"
                    # Paper Tape size
                    "minsize 250 400, title:^(Plover: Paper Tape)$"
                    "maxsize 300 800, title:^(Plover: Paper Tape)$"
                    # Lookup
                    "minsize 300 300, title:^(Plover: Lookup)$"
                    "maxsize 600 600, title:^(Plover: Lookup)$"

                    # Float telegram media viewer popups
                    "float, class:^(org.telegram.desktop)$, title:^(Media viewer)$"
                    "keepaspectratio, class:^(org.telegram.desktop)$, title:^(Media viewer)$" 
                    "size <80% <80%, class:^(org.telegram.desktop)$, title:^(Media viewer)$"

                    # Fix Sharing Indicator of firefox
                    "float, title:(.*)(Sharing Indicator)"
                    "move 50% 2%, title:(.*)(Sharing Indicator)" 
                    "noshadow, title:(.*)(Sharing Indicator)" 
                    "noinitialfocus, title:(.*)(Sharing Indicator)" 

                    # flameshot
                    "suppressevent fullscreen, class:^(flameshot)$"
                    "float, class:^(flameshot)$"
                    "monitor 1, class:^(flameshot)$"
                    "move 0 0, class:^(flameshot)$"
                    "no_anim, class:^(flameshot)$"

                    # Malware aka zoom-us
                    "float, title:^(as_toolbar)$"
                    "pin, title:^(as_toolbar)$"
                    "float, title:^(zoom_linux_float_video_window)$"
                    "pin, title:^(zoom_linux_float_video_window)$"
                    "stayfocused, class:^(zoom)$, title:^(menu window)$"
                    # Zoom chat popup - no focus steal, bottom-right of internal monitor
                    "noinitialfocus, class:^(zoom)$, title:^(Zoom Workplace)$"
                    "monitor ${monitor_internal}, class:^(zoom)$, title:^(Zoom Workplace)$"
                    "move 100%-320 100%-150, class:^(zoom)$, title:^(Zoom Workplace)$"

                    # XWayland stuff
                    "opacity 0.0 override 0.0 override, class:^(xwaylandvideobridge)$"
                    "no_anim, class:^(xwaylandvideobridge)$"
                    "noinitialfocus, class:^(xwaylandvideobridge)$"
                    "maxsize 1 1, class:^(xwaylandvideobridge)$"
                    "noblur, class:^(xwaylandvideobridge)$"
                    "immediate, class:^(steam_app_38400)$"
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
                ]
                ++ (map (w: ws w.key w.n) workspaces)
                ++ (map (w: mvtows w.key w.n) workspaces);

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
              '';
        };
        # UWSM environment configuration for Hyprland
        xdg.configFile."uwsm/env".source = "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";

    };
}
