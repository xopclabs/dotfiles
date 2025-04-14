{ inputs, pkgs, lib, config, ... }:

let 
    cfg = config.modules.hyprland;
    lock = "${pkgs.hyprlock}/bin/hyprlock";
    monitor_internal = "eDP-1";
    monitor_external = "HDMI-A-2";
    cursorTheme = "OpenZone_Black";
    cursorSize = 24;
    hypr-windowrule = pkgs.writeShellScriptBin "hypr-windowrule" ''${builtins.readFile ../hyprland/hypr-windowrule}'';
    bar-restart = pkgs.writeShellScriptBin "bar-restart" ''${builtins.readFile ../hyprland/bar-restart}'';
    autodisable-builtin-keyboard = pkgs.writeShellScriptBin "autodisable-builtin-keyboard" ''${builtins.readFile ../hyprland/autodisable-builtin-keyboard}'';
    enable-builtin-keyboard = pkgs.writeShellScriptBin "enable-builtin-keyboard" ''${builtins.readFile ../hyprland/enable-builtin-keyboard}'';
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
    options.modules.hyprland = { enable = lib.mkEnableOption "hyprland"; };
    imports = [
        #./hyprlock.nix
        ./hypridle.nix
        ./display.nix
    ]; 
    config = lib.mkIf cfg.enable {
        home.packages = [
            pkgs.xwayland pkgs.wlsunset pkgs.wl-clipboard pkgs.wf-recorder pkgs.hypridle  pkgs.socat
            pkgs.libinput
            bar-restart
            hypr-windowrule
            screenrecord
            autodisable-builtin-keyboard
            enable-builtin-keyboard
        ];

        home.pointerCursor = {
            name = cursorTheme;
            package = pkgs.openzone-cursors;
            size = cursorSize;
            gtk.enable = true;
        };

        wayland.windowManager.hyprland = with config.colorScheme.palette; {
            enable = true;
            xwayland.enable = true;
            systemd.enable = true;

            settings = {
                "$terminal" = "kitty -e tm";
                "$newterminal" = "kitty -e tmux";
                "$mod" = "SUPER";
                "$altMod" = "SUPER_CTRL";

                #monitor = [
                #    "${monitor_internal}, 1920x1080@60, 1920x0, 1"
                #    "${monitor_external}, 1920x1080@75, 0x0, 1"
                #];

                exec-once = [
                    "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
                    "hyprctl setcursor ${cursorTheme} ${toString cursorSize}"
                    "swww-daemon"
                    "hypridle"
                    "waybar"
                    "bar-restart"
                    "hypr-windowrule"
                    "tmux new -s main"
                    "[workspace 7 silent] proxychains4 telegram-desktop"
                    "[workspace 8 silent] slack"
                    "freshman_start"
                    "plover"
                ];

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

                gestures = {
                    workspace_swipe = false;
                };

                misc = {
                    disable_hyprland_logo = true;
                    disable_autoreload = true;
                    enable_swallow = true;
                    enable_anr_dialog = false;
                    #swallow_regex = "^(kitty|tmux)$";
                    swallow_regex = "kitty|tmux|(S|s)tremio";
                };

                general  = {
                    allow_tearing = true;
                    layout = "master";
                    resize_on_border = true;
                    gaps_in = 9;
                    gaps_out = "0,0,0,18";
                    border_size = 4;
                    "col.active_border" = "0xff${base0D}";
                    "col.inactive_border" = "0xff${base01}";
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
                        color = "0x8800000";
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
                    # Fix telegram and slack
                    "workspace 7, monitor ${monitor_internal},class:^(telegram-desktop)$"
                    "workspace 8, monitor ${monitor_internal},class:^(slack)$"

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

                    # XWayland stuff
                    "opacity 0.0 override 0.0 override,class:(xwaylandvideobridge)"
                    "noanim,class:(xwaylandvideobridge)"
                    "noinitialfocus,class:(xwaylandvideobridge)"
                    "maxsize 1 1,class:(xwaylandvideobridge)"
                    "noblur,class:(xwaylandvideobridge)"
                    "immediate,class:^(steam_app_38400)$"

                    # IDK why did I needed this
                    "size 40% 40%,class:(org.gnome.Nautilus)"
                ];

                workspace = [
                    "1, monitor:${monitor_external}"
                    "2, monitor:${monitor_external}"
                    "3, monitor:${monitor_external}"
                    "4, monitor:${monitor_external}"
                    "5, monitor:${monitor_internal}"
                    "6, monitor:${monitor_internal}"
                    "7, monitor:${monitor_internal}"
                    "8, monitor:${monitor_internal}"
                ];

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
                        { key = "q"; n = "5"; } 
                        { key = "w"; n = "6"; } 
                        { key = "f"; n = "7"; } 
                        { key = "p"; n = "8"; }
                    ];
                in [
                    "CTRL SHIFT, Slash,  exec, pkill waybar & waybar"
                    "$mod, L, exec, launcher"
                    ", XF86PowerOff, exec, powermenu"
                    ",Print, exec, grim -g \"$(slurp -d)\" - | wl-copy"
                    "SHIFT,Print, exec, screenrecord"
                    "$mod, Space, exec, $terminal"
                    "$altMod, Space, exec, $newterminal"
                    "$mod, H, exec, firefox"
                    "$mod, M, exec, kitty -e ranger"
                    "$mod, Semicolon, exec, ${lock}"

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
                    ",XF86AudioRaiseVolume,  ${e} 'audio.speaker.volume += 0.05; indicator.speaker()'"
                    ",XF86AudioLowerVolume,  ${e} 'audio.speaker.volume -= 0.05; indicator.speaker()'"
                ];

                bindl = [
                    ",switch:on:[Lid switch], exec, enable-builtin-keyboard"
                    ",switch:on:[Lid switch], exec, ${lock}"
                    ",switch:on:[Lid switch], exec, systemctl suspend"
                    ",switch:off:[Lid switch], exec, freshman_start"
                    ",switch:off:[Lid switch], exec, enable-builtin-keyboard"
                
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

        programs.zsh.shellAliases = { startx = "Hyprland"; };
    };
}
