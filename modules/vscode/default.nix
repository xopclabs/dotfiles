{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.vscode;
    vscodePname = config.programs.vscode.package.pname;

    configDir = {
        "vscode" = "Code";
        "cursor" = "Cursor";
    }.${vscodePname};

    sysDir = config.xdg.configHome;
    userSettingsPath = "${sysDir}/${configDir}/User/settings.json";
    userSettingsPathCursor = "${sysDir}/Cursor/User/settings.json";
    keybindingsPath = "${sysDir}/${configDir}/User/keybindings.json";
    keybindingsPathCursor = "${sysDir}/Cursor/User/keybindings.json";
in {
    options.modules.vscode = { 
        enable = mkEnableOption "vscode"; 
        mutable = mkEnableOption "mutable configuration"; 
    };

    config = mkIf cfg.enable {
        home = {
            file.".config/Code/User/settings.json".source = ./settings.json;
            file.".config/Code/User/keybindings.json".source = ./keybindings.json;
            activation = mkIf cfg.mutable {
                removeExistingVSCodeSettings = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
                    rm -rf "${userSettingsPath}"
                    rm -rf "${keybindingsPath}"
                    rm -rf "${userSettingsPathCursor}"
                    rm -rf "${keybindingsPathCursor}"
                '';

                overwriteVSCodeSymlink = let
                    userSettings = readFile ./settings.json;
                    keybindings = readFile ./keybindings.json;
                    jsonSettings = pkgs.writeText "tmp_vscode_settings" userSettings;
                    jsonKeybindings = pkgs.writeText "tmp_vscode_keybindings" keybindings;
                in lib.hm.dag.entryAfter [ "linkGeneration" ] ''
                    rm -rf "${userSettingsPath}"
                    rm -rf "${keybindingsPath}"
                    rm -rf "${userSettingsPathCursor}"
                    rm -rf "${keybindingsPathCursor}"
                    cp ${jsonSettings} "${userSettingsPath}"
                    cp ${jsonKeybindings} "${keybindingsPath}"
                    cp ${jsonSettings} "${userSettingsPathCursor}"
                    cp ${jsonKeybindings} "${keybindingsPathCursor}"
                '';
            };
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
