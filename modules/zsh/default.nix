{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.zsh;
in {
    options.modules.zsh = { 
        enable = mkEnableOption "zsh"; 
        envFile = {
            enable = mkEnableOption "envFile";
            path = mkOption { type = types.path; default="${config.xdg.configHome}/.env"; };
        };
        envExtra = mkOption { type = types.lines; default = ""; };
        initExtraFirst = mkOption { type = types.lines; default = ""; };
        initExtraBeforeCompInit = mkOption { type = types.lines; default = ""; };
        completionInit = mkOption { type = types.lines; default = ""; };
        initExtra = mkOption { type = types.lines; default = ""; };
    };

    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            zsh-fzf-tab
            zsh-fast-syntax-highlighting
        ];

        sops.secrets."env" = mkIf cfg.envFile.enable { 
            path = cfg.envFile.path;
        };

        programs.zsh = {
            enable = true;
            dotDir = ".config/zsh";

            envExtra = cfg.envExtra;
            initExtraFirst = cfg.initExtraFirst;
            initExtraBeforeCompInit = cfg.initExtraBeforeCompInit;
            completionInit = cfg.completionInit;
            initExtra = ''
                # Source env file if exitsts
                if [[ -f "${cfg.envFile.path}" ]]; then
                    source "${cfg.envFile.path}"
                fi

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
            '' + cfg.initExtra;

            history = {
                path = "${config.home.homeDirectory}/.zsh_history";
                share = true;
                ignoreDups = true;
                ignoreAllDups = true;
                ignoreSpace = true;
                findNoDups = true;
                saveNoDups = true;
            };

            enableCompletion = true;
            autosuggestion.enable = true;

            shellAliases = {
                mkdir = "mkdir -vp";
                rm = "rm -rifv";
                mv = "mv -iv";
                cp = "cp -riv";
                cat = "bat --paging=never --style=plain";
                visecret = "sops $NIXOS_CONFIG_DIR/hosts/laptop/secrets.yaml";
            };

            oh-my-zsh = {
                enable = true;
                plugins = [ 
                    "git"
                    "sudo"
                    "aws"
                ];
                extraConfig = ''
                    # Completion
                    zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
                    zstyle ':completion:*' matcher-list 'm:{A-Z}={A-Za-z}'
                '' 
                + ''
                    # fzf-tab
                    zstyle ':completion:*' menu no
                    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons=always $realpath'
                    zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza -1 --color=always --icons=always $realpath'
                    zstyle ':fzf-tab:complete:ls:*' fzf-preview 'eza -1 --color=always --icons=always $realpath'
                    zstyle ':fzf-tab:complete:eza:*' fzf-preview 'eza -1 --color=always --icons=always $realpath'
                    zstyle ':fzf-tab:*' switch-group '<' '>'
                    zstyle ':fzf-tab:*' use-fzf-default-opts yes
                    # Popup in tmux
                    # zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
                '';
            };

            # Source all plugins, nix-style
            plugins = [
                {
                    name = pkgs.zsh-fzf-tab.pname;
                    src = pkgs.zsh-fzf-tab.src;
                    file = "fzf-tab.plugin.zsh";
                }
                {
                    name = pkgs.zsh-fast-syntax-highlighting.pname;
                    src = pkgs.zsh-fast-syntax-highlighting.src;
                    file = "fast-syntax-highlighting.plugin.zsh";
                }
            ];
        };
    };
}
