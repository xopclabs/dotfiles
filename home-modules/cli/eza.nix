{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.cli.eza;

in {
    options.modules.cli.eza = { enable = mkEnableOption "eza"; };
    config = mkIf cfg.enable {
        programs.eza = {
            enable = true;
            enableZshIntegration = false;  # Using smart-ls script instead
            icons = "always";
            colors = "always";
            git = true;
            extraOptions = [
                "--group-directories-first"
                "--header"
            ];
        };

        # Alias ls to smart-ls
        programs.zsh.shellAliases = {
            ls = "smart-ls";
            ll = "smart-ls -l";
            la = "smart-ls -la";
        };
    };
} 