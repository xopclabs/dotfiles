{ inputs, pkgs, config, lib, ... }:

with lib;
let
    cfg = config.modules.desktop.shells.noctalia;
    palette = config.colorScheme.palette;
    icons = import ../../bars/app-icons.nix { inherit lib; };
    aiMeters = import ./ai-meter.nix { inherit pkgs; };

    iconScale = 1.25;
    controlScale = 1.5;

    hardwareCfg = config.metadata.hardware;
    monitors = hardwareCfg.monitors;
    internalMonitors = lib.filter (mon: mon.internal) (lib.attrValues monitors);
    externalMonitors = lib.filter (mon: !mon.internal) (lib.attrValues monitors);
    outputNames = mon: if mon.connectors != [] then mon.connectors else [ mon.name ];
    brightnessMonitor =
        lib.foldl' (acc: mon:
            acc // lib.genAttrs (outputNames mon) (_: { backend = "backlight"; })
        ) {} internalMonitors
        // lib.foldl' (acc: mon:
            acc // lib.genAttrs (outputNames mon) (_: { backend = "ddcutil"; })
        ) {} externalMonitors;

    groupStyle = {
        fill = "#${palette.base01}";
        radius = 0.0;
        padding = 4.0;
        opacity = 1.0;
        widget_spacing = 8;
        accordion = false;
        accordion_direction = "end";
        enabled = true;
    };
    mkGroup = id: members: extra: groupStyle // { inherit id members; } // extra;
in {
    imports = [
        inputs.noctalia.homeModules.default
    ];

    options.modules.desktop.shells.noctalia = {
        enable = mkEnableOption "noctalia shell";

        weather.enable = mkEnableOption "Noctalia weather with a sops-managed location";

        components = {
            bar = mkOption {
                type = types.bool;
                default = true;
                description = "Enable Noctalia's bar component";
            };
            launcher = mkOption {
                type = types.bool;
                default = true;
                description = "Enable Noctalia's launcher component";
            };
        };

        package = mkOption {
            type = types.nullOr types.package;
            default = let
                patched = (inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default or pkgs.noctalia).overrideAttrs (old: {
                    patches = (old.patches or []) ++ (import ../../../../patches { inherit lib; }).noctalia;
                });
            in pkgs.symlinkJoin {
                name = "noctalia";
                paths = [ patched ];
                nativeBuildInputs = [ pkgs.makeWrapper ];
                inherit (patched) meta;
                postBuild = ''
                    rm -f $out/bin/noctalia
                    makeWrapper ${lib.getExe patched} $out/bin/noctalia \
                        --prefix PATH : ${lib.makeBinPath [ pkgs.ddcutil aiMeters.codexbar ]}
                '';
            };
            description = "The noctalia package to use.";
        };

        showOnlyOn = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Restrict the bar to a specific output/monitor. If null, the bar appears on all outputs.";
        };

        settings = mkOption {
            type = types.attrs;
            default = {};
            description = "Settings merged into programs.noctalia.settings.";
        };
    };

    config = mkIf cfg.enable {
        sops.secrets.noctalia-location = mkIf cfg.weather.enable {
            sopsFile = ../../../../secrets/hosts/${config.metadata.hostName}.yaml;
            key = "noctalia-location";
            path = "${config.xdg.configHome}/noctalia/zz-location.toml";
        };

        home.packages = [
            pkgs.ddcutil
            aiMeters.codexbar
            (pkgs.writeShellScriptBin "noctalia-restart" ''
                # Drop GUI overrides so Nix-declared config takes precedence
                settings="''${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/settings.toml"
                if [ -f "$settings" ]; then
                    ${pkgs.python3}/bin/python3 ${./drop-overrides.py} "$settings"
                fi

                # Nix wrapper process name is .noctalia-wrapp, not noctalia.
                pkill -x .noctalia-wrapp >/dev/null 2>&1 || true
                pkill -x noctalia >/dev/null 2>&1 || true
                pkill -f '/bin/\.noctalia-wrapped' >/dev/null 2>&1 || true
                i=0
                while [ "$i" -lt 40 ]; do
                    if ! pgrep -x .noctalia-wrapp >/dev/null 2>&1 \
                        && ! pgrep -x noctalia >/dev/null 2>&1; then
                        break
                    fi
                    i=$((i + 1))
                    sleep 0.05
                done
                exec noctalia -d
            '')
        ];

        programs.noctalia = {
            enable = true;
            inherit (cfg) package;
            customPalettes.base16 = import ./colorscheme.nix { inherit palette; };
            settings = lib.mkMerge [
                {
                    wallpaper.enabled = false;
                    dock.enabled = false;
                    desktop_widgets.enabled = lib.mkDefault false;
                    calendar.enabled = true;
                    weather.enabled = cfg.weather.enable;
                    # hyprlock still owns the lock screen
                    lockscreen.enabled = false;

                    accessibility.ui_scale = 1.15;

                    nightlight = {
                        temperature_day = 10000;
                        temperature_night = 3200;
                    };

                    brightness = {
                        enable_ddcutil = true;
                        monitor = brightnessMonitor;
                    };

                    osd = {
                        border = false;
                        offset_x = 10;
                        orientation = "vertical";
                        position_vertical = "bottom_left";
                        scale = 0.75;
                        kinds = {
                            keyboard_backlight = false;
                            keyboard_layout = false;
                        };
                    };

                    control_center.hidden_tabs = [ "media" ];

                    notification.prefer_app_monitor = true;

                    # Custom palette from the systemwide base16 scheme.
                    # Stylix's noctalia target is disabled so it cannot force
                    # light mode or its own hover/primary mapping.
                    theme = {
                        mode = lib.mkForce "dark";
                        source = lib.mkForce "custom";
                        custom_palette = lib.mkForce "base16";
                        templates = {
                            enable_community_templates = false;
                            community_ids = [ "telegram" ];
                        };
                    };

                    shell = {
                        mpris.blacklist = [
                            "firefox"
                            "chromium"
                            "chrome"
                            "brave"
                            "zen"
                            "vivaldi"
                            "opera"
                            "edge"
                            "floorp"
                            "librewolf"
                            "tor-browser"
                            "epiphany"
                            "ladybird"
                            "thorium"
                            "waterfox"
                        ];
                        font_family = lib.mkForce "Mononoki Nerd Font";
                        app_icon_colorize = false;
                        app_icon_color = "#FFFFFF";
                        app_icon_curve = 0.5;
                        corner_radius_scale = 0.25;
                        niri_overview_type_to_launch_enabled = true;
                        screen_time_enabled = true;
                        telemetry_enabled = true;
                        keyboard_layout.custom_labels = {
                            "English (US)" = "en";
                            "Russian" = "ru";
                        };
                        launcher = {
                            compact = true;
                            show_icons = true;
                            categories = false;
                            providers = {
                                calculator.prefix = "c";
                                emoji.prefix = "e";
                                session.prefix = "s";
                                windows.prefix = "w";
                            };
                        };
                        panel = {
                            transparency_mode = "soft";
                            borders = true;
                            shadow = true;
                            launcher_placement = "attached";
                            launcher_position = "auto";
                            clipboard_placement = "floating";
                            control_center_placement = "attached";
                            session_placement = "attached";
                            open_near_click_control_center = true;
                        };
                    };

                    bar = {
                        order = [ "main" ];
                        main = {
                            enabled = cfg.components.bar && (cfg.showOnlyOn == null);
                            position = "left";
                            thickness = 42;
                            layer = "top";
                            reserve_space = true;
                            background_opacity = 1.0;
                            radius = 0;
                            concave_edge_corners = false;
                            margin_ends = 0;
                            margin_edge = 0;
                            padding = 6;
                            widget_spacing = 6;
                            shadow = true;
                            hover_highlight = true;
                            font_family = "Mononoki Nerd Font";
                            font_weight = 700;
                            font_scale = 1.25;
                            scale = 1.0;
                            capsule = true;
                            capsule_radius = 0.0;
                            capsule_thickness = 1.0;
                            capsule_fill = "#${palette.base01}";
                            capsule_opacity = 1.0;

                            start = [ "launcher" "taskbar" ];
                            center = [];
                            end = [
                                "tray"
                                "privacy"
                                "notifications"
                                "group:status"
                                "group:control"
                                "clock"
                                "group:power"
                            ];
                            capsule_group = [
                                (mkGroup "status" [ "keyboard_layout" "network" "bluetooth" "battery" ] {})
                                (mkGroup "control" [ "volume" "brightness" ] { padding = 2.0; })
                                (mkGroup "power" [ "session" "gamescope" "keyboard" ] {
                                    accordion = true;
                                    accordion_direction = "start";
                                    padding = 6.0;
                                    widget_spacing = 4;
                                })
                            ];
                        } // optionalAttrs (cfg.showOnlyOn != null) {
                            monitor.only = {
                                match = cfg.showOnlyOn;
                                enabled = cfg.components.bar;
                            };
                        };
                    };

                    widget = {
                        launcher = {
                            glyph = "search";
                            scale = iconScale;
                        };
                        taskbar = {
                            group_by_workspace = true;
                            workspace_group_content = "icons";
                            group_single_icon_per_app = false;
                            show_workspace_label = false;
                            workspace_label_placement = "inside";
                            minimal = true;
                            workspace_group_capsule = true;
                            hide_empty_workspaces = true;
                            only_active_workspace = false;
                            show_all_outputs = cfg.showOnlyOn != null;
                            show_active_indicator = false;
                            icon_scale = 1.0;
                            icon_cell = 0.4;
                            icon_source = "glyphs";
                            icon_glyph_default = icons.defaultTabler;
                            icon_glyphs = icons.tablerByAppId;
                            icon_unmapped = "app";
                            capsule = false;
                            capsule_radius = 0.0;
                            focused_color = "#${palette.base0F}";
                            occupied_color = "#${palette.base01}";
                            empty_color = "#${palette.base01}";
                            urgent_color = "#${palette.base08}";
                            active_opacity = 1.0;
                            inactive_opacity = 1.0;
                        };

                        tray = {
                            drawer = true;
                            drawer_columns = 3;
                            drawer_item_size = 20;
                            detached_panel = false;
                            hide_passive = true;
                            scale = controlScale;
                        };
                        privacy = {
                            hide_inactive = true;
                            icon_spacing = 4;
                            active_color = "#${palette.base08}";
                        };
                        notifications = {
                            hide_when_no_unread = false;
                            scale = controlScale;
                        };

                        keyboard_layout = {
                            show_glyph = false;
                            show_label = true;
                            display = "short";
                            scale = iconScale;
                            color = "#${palette.base04}";
                        };
                        network = {
                            show_label = false;
                            vpn_status = "both";
                            scale = controlScale;
                            color = "#${palette.base0C}";
                            actions.left = "panel-toggle control-center";
                        };
                        bluetooth = {
                            show_label = false;
                            scale = controlScale;
                            color = "#${palette.base0D}";
                        };
                        battery = {
                            display_mode = "graphic";
                            show_label = false;
                            label_content = "percent";
                            color = "#${palette.base0B}";
                            warning_color = "#${palette.base08}";
                        };

                        volume = {
                            show_label = false;
                            scale = controlScale;
                            color = "#${palette.base0E}";
                            mute_color = "#${palette.base08}";
                            actions = {
                                left = "volume-mute";
                                right = "panel-toggle control-center audio";
                                scroll_up = "volume-up 5%";
                                scroll_down = "volume-down 5%";
                            };
                        };
                        brightness = {
                            show_label = false;
                            scale = controlScale;
                            color = "#${palette.base0A}";
                            actions = {
                                scroll_up = "brightness-up 5%";
                                scroll_down = "brightness-down 5%";
                            };
                        };

                        clock = {
                            format = "{:%H:%M}";
                            vertical_format = "{:%H\n%M}";
                            tooltip_format = "{:%A, %B %d}";
                            color = "#${palette.base06}";
                        };

                        session = {
                            glyph = "power";
                            scale = iconScale;
                            color = "#${palette.base08}";
                        };
                        gamescope = {
                            type = "custom_button";
                            glyph = "device-gamepad";
                            tooltip = "Gamescope";
                            scale = iconScale;
                            color = "#${palette.base07}";
                            actions.left = "exec sh -c 'if command -v switch-to-gamescope-session >/dev/null; then switch-to-gamescope-session; else start-gamescope-session; fi'";
                        };
                        keyboard = {
                            type = "custom_button";
                            glyph = "keyboard";
                            tooltip = "Disable keyboard";
                            scale = iconScale;
                            color = "#${palette.base0D}";
                            actions.left = "exec keyboard-disable";
                        };
                    };
                }
                cfg.settings
            ];
        };
    };
}
