{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.zsh;
in {
    options.modules.zsh = { 
        enable = mkEnableOption "zsh"; 
        p10k = {
            enable = mkEnableOption "p10k";
        };
        envExtra = mkOption {
            type = types.lines;
            default = "";
            description = "Extra commands that should be added to .zshenv";
        };
        initContent = mkOption {
            type = types.lines;
            default = "";
            description = "Init content that should be added to .zshrc";
        };
        completionInit = mkOption {
            type = types.lines;
            default = "";
        };
    };

    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            zsh
            zsh-fzf-tab
            zsh-fast-syntax-highlighting
        ];

        programs.zsh = {
            enable = true;
            dotDir = ".config/zsh";

            envExtra = cfg.envExtra;
            initContent = lib.mkOrder 100 cfg.initContent;
            completionInit = cfg.completionInit;

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
            historySubstringSearch.enable = true;

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
            ] ++ [
                (mkIf cfg.p10k.enable {
                    name = pkgs.zsh-powerlevel10k.pname;
                    src = pkgs.zsh-powerlevel10k;
                    file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
                })
                (mkIf cfg.p10k.enable {
                    name = "powerlevel10k-config";
                    src = lib.cleanSource ./p10k;
                    file = "p10k.zsh";
                })
            ];

        };
    };
}
