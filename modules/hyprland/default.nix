{ inputs, pkgs, lib, config, ... }:

let 
    cfg = config.modules.hyprland;
    lock = "${pkgs.hyprlock}/bin/hyprlock";
    systemctl = "${pkgs.systemd}/bin/systemctl";
    hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";

    monitor1 = "eDP-1";
    wallpaper = "/home/xopc/.config/ags/assets/nord.png";
in {
    options.modules.hyprland= { enable = lib.mkEnableOption "hyprland"; };
    config = lib.mkIf cfg.enable {
        home.packages = with pkgs; [
            xwayland wlsunset wl-clipboard jq hyprpicker hyprlock hypridle hyprpaper hyprland
        ];

        wayland.windowManager.hyprland = {
            enable = true;
            systemd.enable = true;
            xwayland.enable = true;

            settings = {
                "$terminal" = "tm";
                "$newterminal" = "kitty -e tmux";
                "$mod" = "SUPER";
                "$altMod" = "SUPER_CTRL";

                monitor = [
                    "${monitor1}, 1920x1080@60, 0x0, 1"
                ];

                exec-once = [
                    "hyprpaper"
                    "hypridle"
                    "tmux new -s main"
                    "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
                    "ags -b hypr"
                    "[workspace 7 silent] telegram-desktop"
                    "[workspace 8 silent] slack"
                    "freshman_start"
                ];

                input  = {
                    follow_mouse = true;
                    touchpad = {
                        natural_scroll = true;
                        scroll_factor = 0.25;
                    };
                    tablet = {
                        transform = 2;
                    };
                    kb_layout = "us,ru";
                    kb_options = "grp:alt_shift_toggle";
                };

                gestures = {
                    workspace_swipe = true;
                };

                misc = {
                    disable_hyprland_logo = true;
                    disable_autoreload = true;
                    enable_swallow = true;
                    #swallow_regex = "^(kitty|tmux)$";
                    #swallow_regex = "kitty|tmux";
                    swallow_regex = "tmux";
                };

                general  = {
                    layout = "master";
                    resize_on_border = true;
                    gaps_in = 6;
                    gaps_out = 12;
                    border_size = 4;
                    "col.active_border" = "0xff${config.colorScheme.palette.base0D}";
                    "col.inactive_border" = "0xff${config.colorScheme.palette.base00}";
                };

                decoration = {
                    rounding = 8;
                    drop_shadow = false;
                    shadow_range = 60;
                    "col.shadow" = "0x66000000";
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
                    new_is_master = false;
                };

                windowrule = [
                    "size 40% 40%,^(org.gnome.Nautilus)$"
                ];

                windowrulev2 = [
                    "workspace 7, monitor 1,class:^(telegram-desktop)$"
                    "workspace 8, monitor 1,class:^(slack)$"

                    "float, title:(Picture-in-Picture)"
                    "move onscreen cursor -50 -50, title:(Picture-in-Picture)" 
                    "pin, title:(Picture-in-Picture)" 
                    "keepaspectratio, title:(Picture-in-Picture)" 

                    "float, title:(Extension:)(.*)$"
                    "move onscreen cursor -50 -50, title:(Extension:)(.*)$" 
                    "pin, title:(Extension:)(.*)$" 
                    "keepaspectratio, title:(Extension:)(.*)$" 

                    "float, title:(.*)(Sharing Indicator)$"
                    "move 50% 2%, title:(.*)(Sharing Indicator)$" 
                    "noshadow, title:(.*)(Sharing Indicator)$" 
                    "noinitialfocus, title:(.*)(Sharing Indicator)$" 

                    "opacity 0.0 override 0.0 override,class:(xwaylandvideobridge)"
                    "noanim,class:(xwaylandvideobridge)"
                    "noinitialfocus,class:(xwaylandvideobridge)"
                    "maxsize 1 1,class:(xwaylandvideobridge)"
                    "noblur,class:(xwaylandvideobridge)"
                ];

                # binds
                bind = let
                    binding = mod: cmd: key: arg: "${mod}, ${key}, ${cmd}, ${arg}";
                    mvfocus = binding "$mod" "movefocus";
                    ws = binding "$mod" "workspace";
                    resizeactive = binding "$altMod" "resizeactive";
                    mvwindow = binding "$altMod" "movewindow";
                    mvtows = binding "$altMod" "movetoworkspace";
                    e = "exec, ags -b hypr";
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
                    "CTRL SHIFT, Slash,  ${e} quit; ags -b hypr"
                    "$mod, L,       ${e} -t applauncher"
                    ", XF86PowerOff, ${e} -t powermenu"
                    ",Print, exec, hyprshot -m region -F --clipboard-only"
                    "SHIFT,Print, exec, hyprshot -F --clipboard-only"
                    "$mod, Space, exec, $terminal"
                    "$altMod, Space, exec, $newterminal"
                    "$mod, H, exec, floorp"
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

                bindl = let e = "exec, ags -b hypr -r"; in [
                    ",XF86AudioPlay,    ${e} 'mpris?.playPause()'"
                    ",XF86AudioStop,    ${e} 'mpris?.stop()'"
                    ",XF86AudioPause,   ${e} 'mpris?.pause()'"
                    ",XF86AudioPrev,    ${e} 'mpris?.previous()'"
                    ",XF86AudioNext,    ${e} 'mpris?.next()'"
                    ",XF86AudioMicMute, ${e} 'audio.microphone.isMuted = !audio.microphone.isMuted'"
                    ",switch:on:[Lid switch], exec, systemctl suspend"
                    ",switch:off:[Lid switch], exec, freshman_start"
                    ", XF86Tools, exec, hyprctl switchxkblayout architeuthis-dux 0"
                    ", XF86Tools, exec, hyprctl switchxkblayout sweep-keyboard 0"
                    ", XF86Tools, exec, hyprctl switchxkblayout zmk-project-sweep-keyboard 0"
                    ", XF86Launch5, exec, hyprctl switchxkblayout architeuthis-dux 1"
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
              '';
    };

        programs.zsh.shellAliases = { startx = "Hyprland"; };

        home.file.".config/hypr/hyprlock.conf".text = with config.colorScheme.palette; ''
            $text_color = rgba(${base04}FF)
            $entry_background_color = rgba(${base01}FF)
            $entry_border_color = rgba(${base0D}FF)
            $entry_color = rgba(${base04}FF)
            $font_family = Mononoki Nerd Font
            $font_family_clock = Mononoki Nerd Font

            background {
                path = screenshot
                blur_size = 7
                blur_passes = 4
            }
            input-field {
                monitor = ${monitor1}
                size = 250, 50
                outline_thickness = 2
                dots_size = 0.1
                dots_spacing = 0.3
                outer_color = $entry_border_color
                inner_color = $entry_background_color
                font_color = $entry_color
                # fade_on_empty = true
                rounding = 8

                position = 0, 20
                halign = center
                valign = center
            }

            label { # Clock
                monitor =
                text = $TIME
                color = $text_color
                font_size = 65
                font_family = $font_family_clock

                position = 0, 300
                halign = center
                valign = center
            }
            label { # "locked" text
                monitor =
                text = locked
                color = $text_color
                font_size = 14
                font_family = $font_family

                position = 0, 50
                halign = center
                valign = bottom
            }
        '';

        home.file.".config/hypr/hypridle.conf".text = ''
            listener {
                timeout = 600                              # 10 min
                on-timeout = ${lock}                       # lock screen when timeout has passed
            }

            listener {
                timeout = 300                              # 5min
                on-timeout = ${hyprctl} dispatch dpms off  # screen off when timeout has passed
                on-resume = ${hyprctl} dispatch dpms on    # screen on when activity is detected after timeout has fired.
            }

            listener {
                timeout = 1800                             # 30min
                on-timeout = ${systemctl} suspend          # suspend pc
            }
        '';

        # Wallpaper
        home.file.".config/hypr/hyprpaper.conf".text = ''
            preload = ${wallpaper}
            wallpaper = ${monitor1},${wallpaper}
            splash = false
            ipc = off
        '';
    };
}
