{ pkgs, lib, config, inputs, ... }:

with lib;
let
    cfg = config.modules.tmux;
    theme = with config.colorScheme.colors; ''
        # --> Catppuccin (Dynamic)
        thm_bg=\"#${strings.toLower base00}\"
        thm_fg=\"#${strings.toLower base05}\"
        thm_cyan=\"#${strings.toLower base0C}\"
        thm_black=\"#${strings.toLower base01}\"
        thm_gray=\"#${strings.toLower base01}\"
        thm_magenta=\"#${strings.toLower base0E}\"
        thm_pink=\"#${strings.toLower base0E}\"
        thm_red=\"#${strings.toLower base08}\"
        thm_green=\"#${strings.toLower base0B}\"
        thm_yellow=\"#${strings.toLower base09}\"
        thm_blue=\"#${strings.toLower base0D}\"
        thm_orange=\"#${strings.toLower base0A}\"
        thm_black4=\"#${strings.toLower base00}\"
    '';
    catppuccin-tmux = pkgs.tmuxPlugins.mkTmuxPlugin {
        pluginName = "catppuccin";
        version = "20231130";
        src = pkgs.fetchFromGitHub {
            owner = "omerxx";
            repo = "catppuccin-tmux";
            rev = "e30336b79986e87b1f99e6bd9ec83cffd1da2017";
            sha256 = "sha256-Ig6+pB8us6YSMHwSRU3sLr9sK+L7kbx2kgxzgmpR920=";
        };
        postInstall = ''
            echo "${theme}" > $target/catppuccin-dynamic.tmuxtheme
        '';
    };
in {
    options.modules.tmux = { enable = mkEnableOption "tmux"; };
    config = mkIf cfg.enable {

        programs.tmux = {
            enable = true;
            plugins = with pkgs.tmuxPlugins; [
                vim-tmux-navigator
                yank
                {
                    plugin = inputs.tmux-sessionx.packages.${pkgs.system}.default;
                    extraConfig = ''
                        set -g @sessionx-zoxide-mode 'on'
                        set -g @sessionx-bind 'l'
                        set -g @sessionx-window-height '85%'
                        set -g @sessionx-window-width '75%'
                    '';
                }
                {
                    plugin = catppuccin-tmux;
                    extraConfig = with config.colorScheme.colors; ''
                        set -g @catppuccin_flavour 'dynamic'
                        set -g @catppuccin_window_left_separator "█"
                        set -g @catppuccin_window_right_separator "█ "
                        set -g @catppuccin_window_middle_separator " █"
                        set -g @catppuccin_window_number_position "right"
                        set -g @catppuccin_window_default_fill "number"
                        set -g @catppuccin_window_default_text "#W"
                        set -g @catppuccin_window_current_fill "number"
                        set -g @catppuccin_window_current_background \"#${strings.toLower base01}\"
                        set -g @catppuccin_status_modules_right "directory date_time"
                        set -g @catppuccin_status_modules_left "session"
                        set -g @catppuccin_status_left_separator  " █"
                        set -g @catppuccin_status_right_separator "█ "
                        set -g @catppuccin_status_right_separator_inverse "no"
                        set -g @catppuccin_status_fill "icon"
                        set -g @catppuccin_status_connect_separator "no"
                        set -g @catppuccin_window_current_text "#W#{?window_zoomed_flag,(),}"
                        set -g @catppuccin_directory_text "#{b:pane_current_path}"
                        set -g @catppuccin_date_time_text "%H:%M"
                    '';
                }
            ];

            prefix = "C-b";
            escapeTime = 0;
            customPaneNavigationAndResize = true;
            keyMode = "vi";
            mouse = true;
            clock24 = true;
            shell = "${pkgs.zsh}/bin/zsh";
            terminal = "screen-256color";
            extraConfig = with config.colorScheme.colors; ''
                set-option -sa terminal-overrides ",xterm*:Tc"

                # Layout
                set -g status-position top

                # Vim style pane selection
                bind n select-pane -L
                bind e select-pane -D 
                bind i select-pane -U
                bind o select-pane -R

                # Shift arrow to switch windows
                bind -n S-Left  previous-window
                bind -n S-Right next-window
                bind v copy-mode
                bind-key -T copy-mode-vi v send-keys -X begin-selection
                bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
                bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
                bind-key b set-option status
                bind '"' split-window -v -c "#{pane_current_path}"
                bind % split-window -h -c "#{pane_current_path}"
            '';
        };
    };
}
