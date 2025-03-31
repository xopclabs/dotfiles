{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.vscode;
    vscode = pkgs.vscode.overrideAttrs (old: {
        installPhase = old.installPhase + ''
          rm $out/bin/code
          makeWrapper $out/lib/vscode/code $out/bin/code \
            --add-flags "--enable-features=UseOzonePlatform --ozone-platform=wayland"
        '';
    });
in {
    imports = [
        ./userSettings.nix
        ./keybindings.nix
    ];

    options.modules.vscode = { enable = mkEnableOption "vscode"; };
    config = mkIf cfg.enable {
        programs.vscode = {
            enable = true;
            package = vscode;

            profiles.default = {
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

        # Copy settings and keybindings to Cursor
        home.file = {
            "${config.xdg.configHome}/Code/User/settings.json".onChange = ''
                mkdir -pv ${config.xdg.configHome}/Cursor/User
                cp -av \
                ${config.xdg.configHome}/Code/User/settings.json \
                ${config.xdg.configHome}/Cursor/User
            '';

            "${config.xdg.configHome}/Code/User/keybindings.json".onChange = ''
                mkdir -pv ${config.xdg.configHome}/Cursor/User
                cp -av \
                ${config.xdg.configHome}/Code/User/keybindings.json \
                ${config.xdg.configHome}/Cursor/User
            '';
        };
    };
}
