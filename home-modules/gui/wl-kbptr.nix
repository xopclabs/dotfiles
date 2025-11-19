{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.gui.wl-kbptr;
    colors = config.colorScheme.palette;

in {
    options.modules.gui.wl-kbptr = { enable = mkEnableOption "wl-kbptr"; };
    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            wl-kbptr
            wlrctl
        ];
        
        # Simple key binding for Hyprland
        wayland.windowManager.hyprland.settings.bind = mkIf config.modules.desktop.wm.hyprland.enable [
            "$mod, Backspace, exec, wl-kbptr -c ${config.xdg.configHome}/wl-kbptr/config"
        ];

        home.file."${config.xdg.configHome}/wl-kbptr/config".text = ''
            [general]
            home_row_keys=arstneiowfp
            modes=floating,click

            [mode_floating]
            source=detect
            label_color=#${colors.base05}ff
            label_select_color=#${colors.base05}ff
            label_font_family=monospace
            label_symbols=abcdefghijklmnopqrstuvwxyz
            unselectable_bg_color=#${colors.base00}00
            selectable_bg_color=#${colors.base00}66
            selectable_border_color=#${colors.base08}cc

            [mode_tile]
            label_color=#${colors.base05}ff
            label_select_color=#${colors.base0A}ff
            unselectable_bg_color=#${colors.base00}66
            selectable_bg_color=#${colors.base08}11
            selectable_border_color=#${colors.base08}cc
            label_font_family=monospace
            label_symbols=abcdefghijklmnopqrstuvwxyz

            [mode_bisect]
            label_color=#${colors.base05}ff
            label_font_size=20
            label_font_family=monospace
            label_padding=12
            pointer_size=20
            pointer_color=#${colors.base08}dd
            unselectable_bg_color=#${colors.base00}66
            even_area_bg_color=#${colors.base0D}44
            even_area_border_color=#${colors.base0D}88
            odd_area_bg_color=#${colors.base0E}44
            odd_area_border_color=#${colors.base0E}88
            history_border_color=#${colors.base03}99

            [mode_click]
            button=left
        '';
    };
} 