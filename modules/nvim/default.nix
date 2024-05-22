{  lib, config, pkgs, ... }:
with lib;
let
    cfg = config.modules.nvim;
in {
    options.modules.nvim = { enable = mkEnableOption "nvim"; };
    config = mkIf cfg.enable {
        
        home.packages = with pkgs; [
            nixfmt # Nix
            lua-language-server stylua # Lua
        ];

        programs.neovim = {
            enable = true;
        };

        programs.zsh = {
            initExtra = ''
                export EDITOR="nvim"
            '';

            shellAliases = {
                vim = "nvim -i NONE";
            };
        };

        home.file.".config/nvim" = {
            source = ./nvim;
            recursive = true;
        };

    };
}
