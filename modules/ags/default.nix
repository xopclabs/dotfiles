{ inputs, pkgs, config, ... }:
{
    imports = [ inputs.ags.homeManagerModules.default ];

    home.packages = with pkgs; [
        sassc
        swappy
    ];

    programs.ags = {
        enable = true;
        configDir = ./ags-config;
        extraPackages = with pkgs; [
            libgtop
            libsoup_3
        ];
    };

    xdg.configFile."ags_themes.js".text = with config.colorScheme.palette; ''
        import { Theme, WP, lightColors } from './ags/js/settings/theme.js';

        export default [
            Theme({
                name: 'Nord',
                icon: '󰄛',
                "spacing": 12,
                "padding": 8,
                "radii": 9,
                "popover_padding_multiplier": 1.4,
                "color.red": "#${base08}",
                "color.green": "#${base0B}",
                "color.yellow": "#${base0A}",
                "color.blue": "#${base0D}",
                "color.magenta": "#${base0E}",
                "color.teal": "#${base0C}",
                "color.orange": "#${base09}",
                "theme.scheme": "dark",
                "theme.bg": "#${base00}",
                "theme.fg": "#${base04}",
                "theme.accent.accent": "$blue",
                "theme.accent.fg": "#${base04}",
                "theme.widget.bg": "$fg-color",
                "theme.widget.opacity": 100,
                "border.color": "$fg-color",
                "border.opacity": 100,
                "border.width": 0,
                "hypr.inactive_border": "rgba(${base01}ff)",
                "hypr.wm_gaps_multiplier": 1.5,
                "font.font": "Mononoki Nerd Font",
                "font.mono": "Mononoki Nerd Font",
                "font.size": 15,
                "applauncher.width": 500,
                "applauncher.height": 500,
                "applauncher.icon_size": 30,
                "bar.position": "top",
                "bar.style": "floating",
                "bar.flat_buttons": true,
                "bar.separators": false,
                "bar.icon": "distro-icon",
                "battery.bar.show_icon": true,
                "battery.bar.width": 67,
                "battery.bar.height": 14,
                "battery.bar.full": false,
                "battery.low": 30,
                "battery.medium": 50,
                "desktop.screen_corners": false,
                "desktop.clock.enable": false,
                "desktop.clock.position": "center center",
                "desktop.drop_shadow": true,
                "desktop.shadow": "rgba(0, 0, 0, .3)",
                "notifications.black_list": [
                    "Spotify"
                ],
                "notifications.position": [
                    "top",
                    "right"
                ],
                "notifications.width": 350,
                "dashboard.sys_info_size": 50,
                "mpris.black_list": [
                    "Caprine"
                ],
                "mpris.preferred": "spotify",
                "workspaces": 8
            })
        ];
    '';

}
