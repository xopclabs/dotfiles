{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.editors;
in {
    options.modules.editors.vscode = { enable = mkEnableOption "vscode"; };
    options.modules.editors.cursor = { enable = mkEnableOption "cursor"; };
    config = {

        home.file."${config.xdg.configHome}/Code/User/settings.json".source = (
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/modules/vscode/settings.json"
        );
        home.file."${config.xdg.configHome}/Code/User/keybindings.json".source = (
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/modules/vscode/keybindings.json"
        );
        home.file."${config.xdg.configHome}/Cursor/User/settings.json".source = (
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/modules/vscode/settings.json"
        );
        home.file."${config.xdg.configHome}/Cursor/User/keybindings.json".source = (
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/modules/vscode/keybindings.json"
        );

        home.packages = mkIf cfg.cursor.enable [
            pkgs.code-cursor
        ];

        # Cursor can benefit from VSCode configuration, so enable VSCode as long as anything is enabled
        programs.vscode = mkIf (cfg.vscode.enable || cfg.cursor.enable) {
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
