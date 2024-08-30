{ inputs, pkgs, lib, config, ... }:

let 
    cfg = config.modules.hyprland;
    lock = "${pkgs.hyprlock}/bin/hyprlock";
    monitor1 = "eDP-1";
    monitor2 = "HDMI-A-2";
    cursorTheme = "OpenZone_Black";
    cursorSize = 24;
in {
    options.modules.hyprland = { enable = lib.mkEnableOption "hyprland"; };
    imports = [
        #./hyprlock.nix
        ./hypridle.nix
        ./hyprpaper.nix
    ]; 
    config = lib.mkIf cfg.enable {
        home.packages = with pkgs; [
            xwayland wlsunset wl-clipboard hypridle hyprpaper
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
                "$terminal" = "tm";
                "$newterminal" = "kitty -e tmux";
                "$mod" = "SUPER";
                "$altMod" = "SUPER_CTRL";

                monitor = [
                    "${monitor1}, 1920x1080@60, 1920x0, 1"
                    "${monitor2}, 1920x1080@75, 0x0, 1"
                ];

                exec-once = [
                    "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
                    "hyprctl setcursor ${cursorTheme} ${toString cursorSize}"
                    "hyprpaper"
                    "hypridle"
                    "waybar"
                    "ags -b hypr"
                    "tmux new -s main"
                    "[workspace 7 silent] proxychains4 telegram-desktop"
                    "[workspace 8 silent] proxychains4 slack"
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
                    workspace_swipe = false;
                };

                misc = {
                    disable_hyprland_logo = true;
                    disable_autoreload = true;
                    enable_swallow = true;
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
                    drop_shadow = true;
                    shadow_range = 30;
                    "col.shadow" = "0x8800000";
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
                    "size 40% 40%,^(org.gnome.Nautilus)$"
                ];

                windowrulev2 = [
                    "workspace 7, monitor ${monitor1},class:^(telegram-desktop)$"
                    "workspace 8, monitor ${monitor1},class:^(slack)$"

                    "float, title:(Picture-in-Picture)"
                    "move onscreen cursor -50 -50, title:(Picture-in-Picture)" 
                    "pin, title:(Picture-in-Picture)" 
                    "keepaspectratio, title:(Picture-in-Picture)" 

                    "float, title:^(.*Extension.*)$"
                    "move onscreen cursor -50 -50, title:^(.*Extension.*)$" 
                    "pin, title:^(.*Extension.*)$" 
                    "keepaspectratio, title:^(.*Extension.*)$" 

                    "float, title:(.*)(Sharing Indicator)"
                    "move 50% 2%, title:(.*)(Sharing Indicator)" 
                    "noshadow, title:(.*)(Sharing Indicator)" 
                    "noinitialfocus, title:(.*)(Sharing Indicator)" 

                    "opacity 0.0 override 0.0 override,class:(xwaylandvideobridge)"
                    "noanim,class:(xwaylandvideobridge)"
                    "noinitialfocus,class:(xwaylandvideobridge)"
                    "maxsize 1 1,class:(xwaylandvideobridge)"
                    "noblur,class:(xwaylandvideobridge)"
                    "immediate,class:^(steam_app_38400)$"
                ];

                # workspace rules
                workspace = [
                    "1, monitor:${monitor2}"
                    "2, monitor:${monitor2}"
                    "3, monitor:${monitor2}"
                    "4, monitor:${monitor2}"
                    "5, monitor:${monitor1}"
                    "6, monitor:${monitor1}"
                    "7, monitor:${monitor1}"
                    "8, monitor:${monitor1}"
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
                    "CTRL SHIFT, Slash,  exec, pkill waybar & waybar"
                    "$mod, L, exec, launcher"
                    ", XF86PowerOff, exec, powermenu"
                    ",Print, exec, hyprshot -m region -F --clipboard-only"
                    "SHIFT,Print, exec, hyprshot -F --clipboard-only"
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
                    ",switch:on:[Lid switch], exec, ${lock}"
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
    };
}
