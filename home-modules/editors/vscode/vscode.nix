{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.editors;
    configFiles = {
        settings = "/home/${config.metadata.user}/${config.metadata.repositoryRelPath}/home-modules/editors/vscode/settings.json";
        keybindings = "/home/${config.metadata.user}/${config.metadata.repositoryRelPath}/home-modules/editors/vscode/keybindings.json";
    };
    
    mkEditorConfig = editor: {
        "${config.xdg.configHome}/${editor}/User/settings.json".source = 
            config.lib.file.mkOutOfStoreSymlink configFiles.settings;
        "${config.xdg.configHome}/${editor}/User/keybindings.json".source = 
            config.lib.file.mkOutOfStoreSymlink configFiles.keybindings;
    };
in {
    options.modules.editors.vscode = { enable = mkEnableOption "vscode"; };
    options.modules.editors.cursor = { enable = mkEnableOption "cursor"; };
    config = {

        home.file = mkMerge [
            (mkIf cfg.vscode.enable (mkEditorConfig "Code"))
            (mkIf cfg.cursor.enable (mkEditorConfig "Cursor"))
        ];

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
