{ pkgs, lib, config, inputs, ... }:

with lib;
let
    cfg = config.modules.tmux;
    theme = with config.colorScheme.palette; ''
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
        version = "20240118";
        src = pkgs.fetchFromGitHub {
            owner = "catppuccin";
            repo = "tmux";
            rev = "2ff900dc7a1579085cc2362fe459a1ecff78eec4";
            sha256 = "sha256-78TRFzWUKLR4QuZeiXTa4SzWHxprWav93G21uUKzBfA=";
        };
        postInstall = ''
            echo "${theme}" > $target/catppuccin-dynamic.tmuxtheme
        '';
    };
in {
    options.modules.tmux = { enable = mkEnableOption "tmux"; };
    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            tmux
            tmuxinator
        ];

        programs.tmux = {
            enable = true;
            tmuxinator.enable = true;
            plugins = with pkgs.tmuxPlugins; [
                yank
                {
                    plugin = vim-tmux-navigator;
                    extraConfig = ''
                        bind-key -n C-l if-shell "$is_vim" "send-keys C-l"  "send-keys C-l"
                    '';
                }

                {
                    plugin = inputs.tmux-sessionx.packages.${pkgs.system}.default;
                    extraConfig = ''
                        set -g @sessionx-zoxide-mode 'on'
                        set -g @sessionx-bind 'l'
                        set -g @sessionx-window-height '85%'
                        set -g @sessionx-window-width '75%'
                        set -g @sessionx-preview-location 'right'
                        set -g @sessionx-preview-ratio '55%'
                        set -g @sessionx-filter-current 'false'

                        set -g @sessionx-bind-tree-mode 'ctrl-w'
                        set -g @sessionx-bind-new-window 'ctrl-c'
                        set -g @sessionx-bind-kill-session 'ctrl-d'
                    '';
                }

                {
                    plugin = catppuccin-tmux;
                    extraConfig = with config.colorScheme.palette; ''
                        set -g @catppuccin_flavour 'dynamic'
                        set -g @catppuccin_window_left_separator " █"
                        set -g @catppuccin_window_right_separator "█ "
                        set -g @catppuccin_window_middle_separator "█"
                        set -g @catppuccin_window_number_position "right"
                        set -g @catppuccin_window_default_fill "number"
                        set -g @catppuccin_window_default_text "#W "
                        set -g @catppuccin_window_current_fill "number"
                        set -g @catppuccin_window_current_background "#${strings.toLower base03}"
                        set -g @catppuccin_status_modules_right "date_time"
                        set -g @catppuccin_status_modules_left "session"
                        set -g @catppuccin_status_left_separator  " █"
                        set -g @catppuccin_status_right_separator "█ "
                        set -g @catppuccin_status_right_separator_inverse "no"
                        set -g @catppuccin_status_fill "icon"
                        set -g @catppuccin_status_connect_separator "no"
                        set -g @catppuccin_window_current_text "#W #{?window_zoomed_flag,(),}"
                        set -g @catppuccin_directory_text "#{b:pane_current_path}"
                        set -g @catppuccin_date_time_text "%H:%M"
                    '';
                }

            ];

            prefix = "C-t";
            escapeTime = 0;
            customPaneNavigationAndResize = true;
            disableConfirmationPrompt = true;
            keyMode = "vi";
            mouse = true;
            clock24 = true;
            shell = "${pkgs.zsh}/bin/zsh";
            terminal = "screen-256color";
            extraConfig = with config.colorScheme.palette; ''
                set-option -sa terminal-overrides ",xterm*:Tc"

                # Layout
                set -g status-position top
                set -g renumber-windows on

                # Panes
                bind n select-pane -L
                bind e select-pane -D 
                bind i select-pane -U
                bind o select-pane -R
                bind d kill-pane
                bind q detach-client
                bind b new-window

                # Shift arrow to switch windows
                bind -n S-Left  previous-window
                bind -n S-Right next-window
                bind v copy-mode
                bind-key -T copy-mode-vi v send-keys -X begin-selection
                bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
                bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
                bind-key -n C-l if-shell "$is_vim" "send-keys C-l"  "send-keys C-l"
                bind h split-window -v -c "#{pane_current_path}"
                bind s split-window -h -c "#{pane_current_path}"
            '';
        };
    };
}
