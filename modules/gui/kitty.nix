{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.gui.kitty;

in {
    options.modules.gui.kitty = { enable = mkEnableOption "kitty"; };
    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            kitty
        ];
        programs.kitty = {
            enable = true;
            keybindings = {
                "ctrl+backspace" = "send_text all \\x17";
            };
            settings = with config.colorScheme.palette; {
                font_family = "mononoki Nerd Font";
                adjust_line_height = 5;
                font_size = 18;
                foreground = "#${base04}";
                background = "#${base00}";
                selection_foreground = "#000000";
                selection_background = "#${base0A}";
                url_color = "#${base0E}";
                cursor = "#${base0D}";

                # black
                color0 = "#${base01}";
                color8 = "#${base03}";
                # red
                color1 = "#${base08}";
                color9 = "#${base08}";
                # green
                color2 = "#${base0B}";
                color10 = "#${base0B}";
                # yellow
                color3 = "#${base0A}";
                color11 = "#${base0A}";
                # blue
                color4 = "#${base0D}";
                color12 = "#${base0D}";
                # magenta
                color5 = "#${base0E}";
                color13 = "#${base0E}";
                # cyan
                color6 = "#${base0C}";
                color14 = "#${base0C}";
                # white
                color7 = "#${base05}";
                color15 = "#${base05}";

                # Mouse & cursor
                cursor_shape = "block";
                scrollback_lines = 10000;
                confirm_os_window_close = 0;
                repaint_delay = 10;
                input_delay = 3;
                open_url_with = config.modules.browsers.default;
                enable_audio_bell = "no";
                term = "xterm-kitty";
            };
        };
    };
}
