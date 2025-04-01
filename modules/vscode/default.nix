{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.vscode;
    vscodePname = config.programs.vscode.package.pname;

    configDir = {
        "vscode" = "Code";
        "vscode-insiders" = "Code - Insiders";
        "vscodium" = "VSCodium";
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
            activation = mkIf cfg.mutable {
                removeExistingVSCodeSettings = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
                    rm -rf "${userSettingsPath}"
                    rm -rf "${keybindingsPath}"
                    rm -rf "${userSettingsPathCursor}"
                    rm -rf "${keybindingsPathCursor}"
                '';

                overwriteVSCodeSymlink = let
                    userSettings = config.programs.vscode.profiles.default.userSettings;
                    keybindings = config.programs.vscode.profiles.default.keybindings;
                    jsonSettings = pkgs.writeText "tmp_vscode_settings" (builtins.toJSON userSettings);
                    jsonKeybindings = pkgs.writeText "tmp_vscode_keybindings" (builtins.toJSON keybindings);
                in lib.hm.dag.entryAfter [ "linkGeneration" ] ''
                    rm -rf "${userSettingsPath}"
                    rm -rf "${keybindingsPath}"
                    rm -rf "${userSettingsPathCursor}"
                    rm -rf "${keybindingsPathCursor}"
                    cat ${jsonSettings} | ${pkgs.jq}/bin/jq --monochrome-output > "${userSettingsPath}"
                    cat ${jsonKeybindings} | ${pkgs.jq}/bin/jq --monochrome-output > "${keybindingsPath}"
                    cat ${jsonSettings} | ${pkgs.jq}/bin/jq --monochrome-output > "${userSettingsPathCursor}"
                    cat ${jsonKeybindings} | ${pkgs.jq}/bin/jq --monochrome-output > "${keybindingsPathCursor}"
                '';
            };
        };

        programs.vscode = {
            enable = true;

            profiles.default = {
                userSettings = import ./userSettings.nix;
                keybindings = import ./keybindings.nix;
                extensions = with pkgs.vscode-extensions; [
                    arcticicestudio.nord-visual-studio-code
                    ms-python.python
                    ms-python.vscode-pylance
                    ms-vscode-remote.remote-containers
                    ms-vscode-remote.remote-ssh
                    vscodevim.vim
                ];
            };
        };
    };
}
