{ inputs, pkgs, lib, config, ... }:

let
    cfg = config.modules.desktop.wm.niri;
    hardwareCfg = config.hardware;
    cursorTheme = "OpenZone_Black";
    cursorSize = 24;
in {
    options.modules.desktop.wm.niri = {
        enable = lib.mkEnableOption "niri";
        extraAutostart = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Extra commands to run on startup.";
        };
    };

    config = lib.mkIf cfg.enable {
        home.packages = [
            pkgs.xwayland pkgs.wl-clipboard pkgs.libinput pkgs.jq
        ];

        home.pointerCursor = {
            name = cursorTheme;
            package = pkgs.openzone-cursors;
            size = cursorSize;
            gtk.enable = true;
        };

        programs.niri = with config.colorScheme.palette; {
            enable = true;
            package = pkgs.niri;

            settings = {
                # Input configuration
                input = {
                    keyboard.xkb = {
                        layout = "us,ru";
                        options = "grp:lalt_lshift_toggle,compose:ralt";
                    };
                    touchpad = {
                        tap = true;
                        natural-scroll = true;
                        scroll-factor = 0.5;
                    };
                    tablet.map-to-output = "eDP-1";
                };

                # Layout configuration
                layout = {
                    focus-ring.enable = true;
                    focus-ring.width = 4;
                    border = {
                        enable = true;
                        width = 4;
                    };
                    default-column-display = "normal";
                    preset-column-widths = [
                        { proportion = 0.25; }
                        { proportion = 0.5; }
                        { proportion = 0.75; }
                        { proportion = 1.0; }
                    ];
                    gaps = 16;
                };

                # Hotkey overlays
                # hotkey-overlay.skip-at-startup = true;

                # animations = {
                #     slowdown = 1.0;
                # };

                # Window rules
                window-rules = [
                    # Float telegram media viewer popups
                    {
                        matches = [{ app-id = "^org.telegram.desktop$"; title = "^Media viewer$"; }];
                        open-floating = true;
                        open-maximized = false;
                    }
                    # Float Picture-in-Picture
                    {
                        matches = [{ title = "^Picture-in-Picture$"; }];
                        open-floating = true;
                    }
                    # Float flameshot
                    {
                        matches = [{ app-id = "^flameshot$"; }];
                        open-floating = true;
                    }
                ];

                # Spawn at startup
                spawn-at-startup = [
                    { command = ["dbus-update-activation-environment" "--systemd" "WAYLAND_DISPLAY" "XDG_CURRENT_DESKTOP"]; }
                    { command = ["swww-daemon"]; }
                    { command = ["systemctl" "--user" "start" "waybar"]; }
                ] ++ lib.optional config.modules.cli.tmux.enable { command = ["tmux" "new" "-s" "main"]; }
                  ++ lib.optional config.modules.other.plover.enable { command = ["plover"]; }
                  ++ (map (cmd: { command = [cmd]; }) cfg.extraAutostart);

                # Key bindings
                binds = with config.lib.niri.actions; let
                    mod = "Super";
                    altMod = "Super+Ctrl";
                    spawn = command: { inherit command; };
                in {
                    # Terminal
                    "${mod}+Space" = spawn "${config.modules.terminals.default} -e tm";
                    "${altMod}+Space" = spawn "${config.modules.terminals.default} -e tmux";

                    # Browser
                    "${mod}+H" = spawn config.modules.browsers.default;

                    # Launcher
                    "${mod}+L" = spawn "${config.modules.desktop.launchers.default}-drun";

                    # Screenshots
                    "Print" = spawn "screenshot";
                    "Ctrl+Print" = spawn "annotate";
                    "Ctrl+Shift+Print" = spawn "screenrecord";

                    # Window management
                    "${mod}+D" = close-window;
                    "${mod}+U" = {
                        action = toggle-window-floating;
                        repeat = false;
                    };
                    "${mod}+Z" = toggle-window-fullscreen;

                    # Focus movement (vim-like)
                    "${mod}+N" = focus-window-left;
                    "${mod}+E" = focus-window-down;
                    "${mod}+I" = focus-window-up;
                    "${mod}+O" = focus-window-right;

                    # Window movement
                    "${altMod}+N" = move-window-left;
                    "${altMod}+E" = move-window-down;
                    "${altMod}+I" = move-window-up;
                    "${altMod}+O" = move-window-right;

                    # Workspaces
                    "${mod}+A" = focus-workspace 1;
                    "${mod}+R" = focus-workspace 2;
                    "${mod}+S" = focus-workspace 3;
                    "${mod}+T" = focus-workspace 4;
                    "${mod}+G" = focus-workspace 5;
                    "${mod}+Q" = focus-workspace 6;
                    "${mod}+W" = focus-workspace 7;
                    "${mod}+F" = focus-workspace 8;
                    "${mod}+P" = focus-workspace 9;
                    "${mod}+B" = focus-workspace 10;

                    # Move windows to workspaces
                    "${altMod}+A" = move-window-to-workspace 1;
                    "${altMod}+R" = move-window-to-workspace 2;
                    "${altMod}+S" = move-window-to-workspace 3;
                    "${altMod}+T" = move-window-to-workspace 4;
                    "${altMod}+G" = move-window-to-workspace 5;
                    "${altMod}+Q" = move-window-to-workspace 6;
                    "${altMod}+W" = move-window-to-workspace 7;
                    "${altMod}+F" = move-window-to-workspace 8;
                    "${altMod}+P" = move-window-to-workspace 9;
                    "${altMod}+B" = move-window-to-workspace 10;

                    # Quit
                    "Ctrl+Alt+Delete" = quit;

                    # Brightness
                    "XF86MonBrightnessUp" = spawn "brightnessctl s +5%";
                    "XF86MonBrightnessDown" = spawn "brightnessctl s 5%-";
                    "XF86KbdBrightnessUp" = spawn "brightnessctl -d '*kbd*' s +1";
                    "XF86KbdBrightnessDown" = spawn "brightnessctl -d '*kbd*' s 1-";

                    # Volume
                    "XF86AudioRaiseVolume" = spawn "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
                    "XF86AudioLowerVolume" = spawn "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
                };

                # Environment variables
                environment."NIXOS_OZONE_WL" = "1";
                environment."XCURSOR_THEME" = cursorTheme;
                environment."XCURSOR_SIZE" = toString cursorSize;
            };
        };

        programs.zsh.shellAliases = { startx = "niri"; };
    };
}
