{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.fzf;

in {
    options.modules.fzf = { enable = mkEnableOption "fzf"; };

    config = mkIf cfg.enable {

        home.packages = with pkgs; [
            fd
        ];

        programs.fzf = {
            enable = true;
            enableZshIntegration = true;
            defaultCommand = "fd --type f --hidden --exclude .git";
            fileWidgetCommand = "fd --type f --hidden --exclude .git";
            changeDirWidgetCommand = "fd --type d --hidden --exclude .git";
            colors = with config.colorScheme.palette; {
                fg = "#${base05}";
                "fg+" = "#${base06}";
                bg = "#${base00}";
                "bg+" = "#${base01}";
                hl = "#${base0D}";
                "hl+" = "#${base0D}";
                info = "#${base0A}";
                prompt = "#${base0E}";
                pointer = "#${base0C}";
                marker = "#${base0B}";
                spinner = "#${base0E}";
                header = "#${base05}";
            };
            fileWidgetOptions = [
                "--preview 'bat --color=always --style=numbers --line-range=:500 {}' --bind 'ctrl-/:change-preview-window(down|hidden|)'"
            ];
            changeDirWidgetOptions = [
                "--preview 'eza -1 --color=always --icons=always {}'"
            ];
            historyWidgetOptions = [
                "--sort --exact"
            ];
        };

        programs.zsh.initContent = lib.mkOrder 1000 ''
            export FZF_COMPLETION_TRIGGER=""
            bindkey '^S' fzf-completion
            bindkey '^I' $fzf_default_completion

            # Modified fzf function that uses the smart preview.
            _fzf_comprun() {
                local command=$1
                shift

                case "$command" in
                    cd|mv|cp|rm) fzf "$@" --preview 'see {}' ;;
                    cursor|code|nvim|vim|bat|cat)
                        fzf "$@" --walker file,hidden --preview 'see {}' --bind 'ctrl-/:change-preview-window(down|hidden|)' ;;
                    *) fzf "$@" ;;
                esac
            }
        '';

    };
}
