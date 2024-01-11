{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.kitty;

in {
    options.modules.kitty = { enable = mkEnableOption "kitty"; };
    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            kitty
        ];
        programs.kitty = {
            enable = true;
            keybindings = {
		"ctrl+backspace" = "send_text all \\x17";
            };
	    settings = {
		font_family = "mononoki Nerd Font";
                adjust_line_height = 5;
		font_size = 18;
		foreground = "#D8DEE9";
		background = "#2E3440";
		selection_foreground = "#000000";
		selection_background = "#EBCB8B";
		url_color = "#B48EAD";
		cursor = "#81A1C1";

		# black
		color0 = "#3B4252";
		color8 = "#4C566A";
		# red
		color1 = "#BF616A";
		color9 = "#BF616A";
		# green
		color2 = "#A3BE8C";
		color10 = "#A3BE8C";
		# yellow
		color3 = "#EBCB8B";
		color11 = "#EBCB8B";
		# blue
		color4 = "#81A1C1";
		color12 = "#81A1C1";
		# magenta
		color5 = "#B48EAD";
		color13 = "#B48EAD";
		# cyan
		color6 = "#88C0D0";
		color14 = "#8FBCBB";
		# white
		color7 = "#E5E9F0";
		color15 = "#B48EAD";

		# Mouse & cursor
		cursor_shape = "block";
		scrollback_lines = 10000;
		confirm_os_window_close = 0;
		repaint_delay = 10;
		input_delay = 3;
		open_url_with = "firefox";
 		enable_audio_bell = "no";
		term = "xterm-kitty";
            };
        };
    };
}
