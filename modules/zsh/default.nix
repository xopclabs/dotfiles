{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.zsh;
in {
    options.modules.zsh = { 
        enable = mkEnableOption "zsh"; 
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
    };

    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            zsh
            #zsh-powerlevel10k
        ];

        programs.zsh = {
            enable = true;
            oh-my-zsh = {
                enable = true;
                plugins = [ "git"];
            };
            dotDir = ".config/zsh";

            history = {
                path = "/home/${config.home.username}/.zsh_history";
                ignoreAllDups = true;
            };

            envExtra = cfg.envExtra;
            initContent = cfg.initContent;

            enableCompletion = true;
            autosuggestion.enable = true;
            syntaxHighlighting.enable = true;

            # Set some aliases
            shellAliases = {
                mkdir = "mkdir -vp";
                rm = "rm -rifv";
                mv = "mv -iv";
                cp = "cp -riv";
                cat = "bat --paging=never --style=plain";
                ls = "eza --icons=automatic";
                tree = "eza --tree --icons=automatic";
                grep = "grep";
                reconfig = "STARTDIR=$(pwd); cd $NIXOS_CONFIG_DIR; sudo nixos-rebuild switch --flake \"$NIXOS_CONFIG_DIR?submodules=1\" --fast; cd $STARTDIR";
                visecret = "sops $NIXOS_CONFIG_DIR/hosts/laptop/secrets.yaml";
            };

            # Source all plugins, nix-style
            plugins = [
                # {
                #     name = "powerlevel10k";
                #     src = pkgs.zsh-powerlevel10k;
                #     file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
                # }
                # {
                #     name = "powerlevel10k-config";
                #     src = lib.cleanSource ./p10k;
                #     file = "p10k.zsh";
                # }
            ];

        };
    };
}
