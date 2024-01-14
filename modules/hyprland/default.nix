{ inputs, pkgs, lib, config, ... }:

let cfg = config.modules.hyprland;
in {
    options.modules.hyprland= { enable = lib.mkEnableOption "hyprland"; };
    config = lib.mkIf cfg.enable {
        home.packages = with pkgs; [
            wayshot swww swaylock-effects swayidle xwayland wlsunset wl-clipboard hyprland
        ];

        wayland.windowManager.hyprland = {
            enable = true;
            systemd.enable = true;
            xwayland.enable = true;

            settings = {
                "$terminal" = "kitty";
                "$mod" = "SUPER";
                "$altMod" = "SUPER_CTRL";

                monitor = [
                    "eDP-1, 1920x1080@60, 0x0, 1"
                ];

                exec-once = [
                    "ags -b hypr"
                ];

                input  = {
                    follow_mouse = true;
                    touchpad = {
                        natural_scroll = true;
                        scroll_factor = 0.25;
                    };
                    kb_layout = "us,ru";
                    kb_options = "grp:alt_shift_toggle";
                };

                "device:kensington-expert-mouse" = {
                    sensitivity = -0.35;
                    accel_profile = "flat";
                };

                gestures = {
                    workspace_swipe = true;
                };

                misc = {
                    disable_hyprland_logo = true;
                    disable_autoreload = true;
                    enable_swallow = true;
                };

                general  = {
                    layout = "master";
                    resize_on_border = true;
                    gaps_in = 6;
                    gaps_out = 12;
                    border_size = 4;
                    "col.active_border" = "0xff${config.colorScheme.colors.base0D}";
                    "col.inactive_border" = "0xff${config.colorScheme.colors.base00}";
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
                        "windows,1,4,default,slide"
                        "workspaces,1,6,default,slide"
                    ];
                };

                master = {
                    mfact = 0.6;
                    new_is_master = false;
                };

                windowrulev2 = [
                    "workspace 7, monitor 1,class:^(telegram-desktop)$"
                    "workspace 8, monitor 1,class:^(slack)$"
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
                    ", XF86Launch4,  ${e} -r 'recorder.start()'"
                    ",Print,         ${e} -r 'recorder.screenshot()'"
                    "SHIFT,Print,    ${e} -r 'recorder.screenshot(true)'"
                    "$mod, Space, exec, $terminal" # xterm is a symlink, not actually xterm
                    "$mod, H, exec, firefox"
                    "$mod, M, exec, $terminal -e ranger"
                    "$mod, Semicolon, exec, swaylock -f"

                    "$mod, D, killactive"
                    "$mod, U, togglefloating"
                    "$mod, Y, fullscreen"
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
                ];
            };
        };

        programs.zsh.shellAliases = { startx = "Hyprland"; };

        # Swaylock
        programs.swaylock = {
            enable = true;
            package = pkgs.swaylock-effects;
            settings = with config.colorScheme.colors; let 
                black = base03;
                white = base04;
                blue = base0D;
                red = base08;
                orange = base09;
                yellow = base0A;
                green = base0B;
                transparent = "ffffff00";
            in {
                screenshots = true;
                indicator = true;
                disable-caps-lock-text = true;
                #grace = 2;
                effect-blur = "30x5";
                font = "Mononoki Nerd Font";
                font-size = 18;
                # Static
                ring-color = white;
                inside-color = black;
                ring-clear-color = green;
                inside-clear-color = black;
                ring-caps-lock-color = orange;
                inside-caps-lock-color = black;
                ring-ver-color = yellow;
                inside-ver-color = black;
                ring-wrong-color = red;
                inside-wrong-color = black;
                line-uses-ring = true;
                separator-color = transparent;
                text-color = transparent;
                text-clear-color = transparent;
                text-caps-lock-color = transparent;
                text-ver-color = transparent;
                text-wrong-color = transparent;
                layout-bg-color = transparent;
                layout-border-color = transparent;
                layout-text-color = white;
                # Reactive
                key-hl-color = green;
                bs-hl-color = red;
                caps-lock-bs-hl-color = orange;
                caps-lock-key-hl-color = orange;
            };
        };

        # Swayidle
        services.swayidle = {
            enable = true;
            events = [
                { event = "before-sleep"; command = "${pkgs.swaylock}/bin/swaylock"; }
            ];
            timeouts = [
                { timeout = 180; command = "${pkgs.swaylock-effects}/bin/swaylock -f"; }
                { timeout = 1200; command = "${pkgs.systemd}/bin/systemctl hibernate"; }
            ];
        };
    };
}
