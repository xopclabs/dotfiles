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
                plugins = [ "git" ];
            };
            dotDir = ".config/zsh";

            enableCompletion = true;
            enableAutosuggestions = true;
            syntaxHighlighting.enable = true;

            # Tweak settings for history
            history = {
                path = "$HOME/.cache/zsh_history";
            };

            # Set some aliases
            shellAliases = {
                mkdir = "mkdir -vp";
                rm = "rm -rifv";
                mv = "mv -iv";
                cp = "cp -riv";
                cat = "bat --paging=never --style=plain";
                ls = "eza --icons=automatic";
                tree = "eza --tree --icons=automatic";
                reconfig = "sudo nixos-rebuild switch --flake $NIXOS_CONFIG_DIR --fast";
            };

            # Source all plugins, nix-style
            plugins = [
            {
                name = "auto-ls";
                src = pkgs.fetchFromGitHub {
                    owner = "notusknot";
                    repo = "auto-ls";
                    rev = "62a176120b9deb81a8efec992d8d6ed99c2bd1a1";
                    sha256 = "08wgs3sj7hy30x03m8j6lxns8r2kpjahb9wr0s0zyzrmr4xwccj0";
                };
            }
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
