{ inputs, pkgs, lib, config, ... }:

let
    cfg = config.modules.desktop.wm.hyprland;
    lock = "${pkgs.hyprlock}/bin/hyprlock";
    hardwareCfg = config.hardware;
    monitor_internal = "desc:${hardwareCfg.monitors.internal.name}";
    monitor_external = "desc:${hardwareCfg.monitors.external.name}";
    cursorTheme = "OpenZone_Black";
    cursorSize = 24;
    hypr-windowrule = pkgs.writeShellScriptBin "hypr-windowrule" ''${builtins.readFile ./scripts/hypr-windowrule}'';
    bar-restart = pkgs.writeShellScriptBin "bar-restart" ''${builtins.readFile ./scripts/bar-restart}'';
    toggle-keyboard = pkgs.writeShellScriptBin "toggle-keyboard" ''${builtins.readFile ./scripts/toggle-keyboard}'';
    monitor-dpms = pkgs.writeShellScriptBin "monitor-dpms" ''
        ${builtins.replaceStrings 
            ["@INTERNAL_MONITOR@" "@EXTERNAL_MONITOR@"] 
            [hardwareCfg.monitors.internal.name hardwareCfg.monitors.external.name] 
            (builtins.readFile ./scripts/monitor-dpms)
        }
    '';
    screenshot = pkgs.writeShellScriptBin "screenshot" ''
    	grim -g "$(slurp -d)" - | wl-copy
    '';
    annotate = pkgs.writeShellScriptBin "annotate" ''
        wl-paste | swappy -f - -o - | wl-copy
    '';
    screenrecord = pkgs.writeShellScriptBin "screenrecord" ''
        # Check if wf-recorder is currently running
        if pgrep -x wf-recorder > /dev/null; then
            echo "Stopping wf-recorder..."
            pkill -SIGINT wf-recorder
        else
            echo "Starting wf-recorder..."
            wf-recorder -g "$(slurp)" -f ~/screenshots/$(date +'%Y-%m-%d_%H-%M-%S').mkv &
        fi
    '';
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
    config = lib.mkIf cfg.enable {
        home.packages = [
            pkgs.xwayland pkgs.wlsunset pkgs.wl-clipboard pkgs.wf-recorder pkgs.socat
            pkgs.libinput pkgs.jq
            hypr-windowrule
            screenshot
            annotate pkgs.swappy
            screenrecord
            toggle-keyboard
            monitor-dpms
        ];

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

                # We define monitors with kanshi
                #monitor = [
                #    "${monitor_external}, 1920x1080@74.97, 0x0, 1"
                #    "${monitor_internal}, 1920x1080@60, 1920x0, 1"
                #];

                exec-once = [
                    "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
                    "hyprctl setcursor ${cursorTheme} ${toString cursorSize}"
                    "swww-daemon"
                    "hypr-windowrule"
                    "[workspace 8 silent] telegram-desktop"
                    "[workspace 9 silent] slack"
                ] ++ lib.optional config.modules.desktop.bars.waybar.enable "waybar"
                  ++ lib.optional config.modules.cli.tmux.enable "tmux new -s main"
                  ++ lib.optional config.modules.gui.plover.enable "plover"
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

                windowrule = [
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
                    "float, class:org.telegram.desktop, title:Media viewer"
                    "keepaspectratio, class:org.telegram.desktop, title:Media viewer" 
                    "size <80% <80%, class:org.telegram.desktop, title:Media viewer"

                    # Fix Shaing Indicator of firefox
                    "float, title:(.*)(Sharing Indicator)"
                    "move 50% 2%, title:(.*)(Sharing Indicator)" 
                    "noshadow, title:(.*)(Sharing Indicator)" 
                    "noinitialfocus, title:(.*)(Sharing Indicator)" 

                    # flameshot
                    "suppressevent fullscreen, class:flameshot"
                    "float, class:flameshot"
                    "monitor 1, class:flameshot"
                    "move 0 0, class:flameshot"
                    "noanim, class:flameshot"

                    # Malware aka zoom-us
                    "float, title:as_toolbar"
                    "pin, title:as_toolbar"
                    "float, title:zoom_linux_float_video_window"
                    "pin, title:zoom_linux_float_video_window"
                    "stayfocused, class:zoom, title:menu window"

                    # XWayland stuff
                    "opacity 0.0 override 0.0 override,class:(xwaylandvideobridge)"
                    "noanim,class:(xwaylandvideobridge)"
                    "noinitialfocus,class:(xwaylandvideobridge)"
                    "maxsize 1 1,class:(xwaylandvideobridge)"
                    "noblur,class:(xwaylandvideobridge)"
                    "immediate,class:^(steam_app_38400)$"
                ];

                layerrule = [
                    "noanim, waybar"
                    "noanim, launcher"
                    "noanim, selection"
                    # Launcher under waybar
                    "order -1, launcher"
                ];
                workspace = [
                    "1, monitor:${monitor_external}, default:true"
                    "2, monitor:${monitor_external}"
                    "3, monitor:${monitor_external}"
                    "4, monitor:${monitor_external}"
                    "5, monitor:${monitor_external}"
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
                ] else if cfg.disableGapsOutOn != null && cfg.disableGapsOutOn == hardwareCfg.monitors.external.name then [
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
                bindle = let e = "exec, ags -b hypr -r"; in [
                    ",XF86MonBrightnessUp,   ${e} 'brightness.screen += 0.05; indicator.display()'"
                    ",XF86MonBrightnessDown, ${e} 'brightness.screen -= 0.05; indicator.display()'"
                    ",XF86KbdBrightnessUp,   ${e} 'brightness.kbd++; indicator.kbd()'"
                    ",XF86KbdBrightnessDown, ${e} 'brightness.kbd--; indicator.kbd()'"
                    ",XF86AudioRaiseVolume,  ${e} 'audio.speaker.volume += 0.1; indicator.speaker()'"
                    ",XF86AudioLowerVolume,  ${e} 'audio.speaker.volume -= 0.1; indicator.speaker()'"
                ];

                bindl = [
                    ",switch:on:[Lid switch], exec, ${lock}"
                    ",switch:on:[Lid switch], exec, systemctl suspend"
                    ",switch:off:[Lid switch], exec, freshman_start"
                
                    # F13, F14 binds for keyboard layouts
                    ", XF86Tools, exec, hyprctl switchxkblayout sweep-keyboard 0"
                    ", XF86Tools, exec, hyprctl switchxkblayout zmk-project-sweep-keyboard 0"
                    ", XF86Launch5, exec, hyprctl switchxkblayout sweep-keyboard 1"
                    ", XF86Launch5, exec, hyprctl switchxkblayout zmk-project-sweep-keyboard 1"
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

        programs.zsh.shellAliases = { startx = "Hyprland"; };

    };
}
