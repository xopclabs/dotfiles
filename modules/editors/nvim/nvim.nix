{  lib, config, pkgs, ... }:
with lib;
let
    cfg = config.modules.editors.nvim;
in {
    options.modules.editors.nvim = { enable = mkEnableOption "nvim"; };
    config = mkIf cfg.enable {
        
        home.packages = with pkgs; [
            nixfmt-classic # Nix
            lua-language-server stylua # Lua
        ];

        programs.neovim = {
            enable = true;
        };

        programs.zsh = mkIf config.modules.cli.zsh.enable {
            initContent = mkIf (config.modules.editors.default == "nvim") (
                mkOrder 1000 ''
                    export EDITOR="nvim"
                ''
            );
            shellAliases = {
                vim = "nvim -i NONE";
            };
        };

    };
}
