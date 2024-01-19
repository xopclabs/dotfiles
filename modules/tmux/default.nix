{ pkgs, lib, config, ... }:

with lib;
let
    cfg = config.modules.tmux;
in {
    options.modules.tmux = { enable = mkEnableOption "tmux"; };
    config = mkIf cfg.enable {
        programs.tmux = {
            enable = true;
            plugins = with pkgs.tmuxPlugins; [
                vim-tmux-navigator
                yank
            ];
            prefix = "C-b";
            escapeTime = 0;
            keyMode = "vi";
            mouse = true;
            clock24 = true;
            shell = "${pkgs.zsh}/bin/zsh";
            terminal = "screen-256color";
            extraConfig = ''
                set-option -sa terminal-overrides ",xterm*:Tc"
                                                                                        unbind C-b
                # Vim style pane selection
                bind n select-pane -L
                bind e select-pane -D 
                bind i select-pane -U
                bind o select-pane -R
                # Shift arrow to switch windows
                bind -n S-Left  previous-window
                bind -n S-Right next-window
                                                                                        set -g prefix C-Space
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
