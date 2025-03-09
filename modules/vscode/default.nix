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
    options.modules.vscode = { enable = mkEnableOption "vscode"; };
    config = mkIf cfg.enable {
        programs.vscode = {
            enable = true;
            package = vscode;
            profiles.default = {
                extensions = with pkgs.vscode-extensions; [
                    arcticicestudio.nord-visual-studio-code
                    #ms-python.python
                    ms-python.vscode-pylance
                    ms-vscode-remote.remote-containers
                    ms-vscode-remote.remote-ssh
                    vscodevim.vim
                ];
                userSettings = {
                   "window.titleBarStyle" = "custom";
                   "workbench.colorTheme" = "Nord";
                   "editor.fontSize" = 20;
                   "editor.fontFamily" = "'Mononoki Nerd Font','Monaco','Droid Sans Mono', 'monospace', monospace";
                   "editor.minimap.enabled" = false;
                   "telemetry.telemetryLevel" = "off";
                   "explorer.confirmDragAndDrop" = false;
                   "git.confirmSync" = false;
                   "explorer.confirmDelete" = false;
                   "dev.containers.copyGitConfig" = true;
                   #"dev.containers.gitCredentialHelperConfigLocation" = "none";
                   "notebook.cellToolbarLocation" = {
                       "default" = "right";
                       "jupyter-notebook" = "right";
                   };
                   "editor.inlineSuggest.enabled" = true;
                   "editor.suggestSelection" = "first";
                   "editor.tabSize" = 4;
                   "editor.wordWrap" = "off";
                   "git.autofetch" = true;
                   "git.defaultBranchName" = "main";
                   "python.languageServer" = "Pylance";
                   "terminal.integrated.fontFamily" = "'mononoki Nerd Font'";
                   "remote.autoForwardPortsSource" = "hybrid";
                   "jupyter.widgetScriptSources" = [
                       "jsdelivr.com"
                       "unpkg.com"
                   ];
                   "jupyter.askForKernelRestart" = false;

                   "vim.easymotion" = true;
                   "files.exclude" = {
                        "**/__pycache__" = true;
                        "**/.ipynb_checkpoints" = true;
                    };
                   "search.exclude" = {
                        "**/__pycache__" = true;
                        "**/.ipynb_checkpoints" = true;
                        "**/node_modules" = true;
                        "**/build" = true;
                    };
                };
            };
        };
    };
}
