{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.zsh;
in {
    options.modules.zsh = { enable = mkEnableOption "zsh"; };

    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            zsh
            zsh-powerlevel10k
        ];

        programs.zsh = {
            enable = true;
            oh-my-zsh = {
                enable = true;
                plugins = [ "git"];
            };
            dotDir = ".config/zsh";

            history = {
                path = "/home/xopc/.zsh_history";
                ignoreAllDups = true;
            };


            enableCompletion = true;
            enableAutosuggestions = true;
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
                reconfig = "STARTDIR=$(pwd); cd $NIXOS_CONFIG_DIR; nix flake lock --update-input zmk-nix; sudo nixos-rebuild switch --flake .?submodules=1 --fast; cd $STARTDIR";
            };

            # Source all plugins, nix-style
            plugins = [
                {
                    name = "powerlevel10k";
                    src = pkgs.zsh-powerlevel10k;
                    file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
                }
                {
                    name = "powerlevel10k-config";
                    src = lib.cleanSource ./p10k;
                    file = "p10k.zsh";
                }
            ];

        };
    };
}
