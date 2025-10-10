{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.cli.zsh;
in {
    options.modules.cli.zsh = { 
        enable = mkEnableOption "zsh"; 
        envFile = {
            enable = mkEnableOption "envFile";
            path = mkOption { type = types.path; default="${config.xdg.configHome}/.env"; };
        };
        envExtra = mkOption { type = types.lines; default = ""; };
        initContentFirst = mkOption { type = types.lines; default = ""; };
        initContentBeforeCompInit = mkOption { type = types.lines; default = ""; };
        completionInit = mkOption { type = types.lines; default = ""; };
        initContent = mkOption { type = types.lines; default = ""; };
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
            dotDir = "${config.xdg.configHome}/zsh";

            envExtra = lib.mkMerge [
                cfg.envExtra
                (lib.mkIf cfg.envFile.enable ''
                    # Source env file if exists
                    if [[ -f "${cfg.envFile.path}" ]]; then
                        source "${cfg.envFile.path}"
                    fi
                '')
            ];
            completionInit = cfg.completionInit;
            initContent = lib.mkMerge [
                # Before everything
                (lib.mkOrder 500 cfg.initContentFirst)
                # Before comp init
                (lib.mkOrder 550 cfg.initContentBeforeCompInit)
                # Default place
                (lib.mkOrder 1000 cfg.initContent)
                # After everything
                #(lib.mkOrder 1500 "")
            ];

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
                rm = "rm -iv";
                mv = "mv -iv";
                cp = "cp -riv";
                grep = "grep --color=auto";
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

