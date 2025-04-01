{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.vscode;
in {
    options.modules.vscode = { enable = mkEnableOption "vscode"; };

    config = mkIf cfg.enable {

        home.file = {
            "${config.xdg.configHome}/Code/User/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/modules/vscode/settings.json";
            "${config.xdg.configHome}/Code/User/keybindings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/modules/vscode/keybindings.json";
            "${config.xdg.configHome}/Cursor/User/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/modules/vscode/settings.json";
            "${config.xdg.configHome}/Cursor/User/keybindings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/modules/vscode/keybindings.json";
        };

        programs.vscode = {
            enable = true;
            profiles.default = {
                extensions = with pkgs.vscode-extensions; [
                    arcticicestudio.nord-visual-studio-code
                    ms-python.python
                    ms-python.vscode-pylance
                    ms-toolsai.jupyter-keymap
                    ms-vscode-remote.remote-containers
                    ms-vscode-remote.remote-ssh
                    vscodevim.vim
                    mkhl.direnv
                    bbenoist.nix
                ];
            };
        };
    };
}
