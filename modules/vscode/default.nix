{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.vscode;
in {
    options.modules.vscode = { enable = mkEnableOption "vscode"; };
    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            vscode
        ];
	programs.vscode = {
            enable = true;
            extensions = with pkgs.vscode-extensions; [
                arcticicestudio.nord-visual-studio-code
		ms-python.python
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
               "dev.containers.copyGitConfig" = false;
               "dev.containers.gitCredentialHelperConfigLocation" = "none";
               "notebook.cellToolbarLocation" = {
                   "default" = "right";
                   "jupyter-notebook" = "right";
               };
	       "editor.inlineSuggest.enabled" = true;
	       "editor.suggestSelection" = "first";
	       "editor.tabSize" = 4;
	       "editor.wordWrap" = "off";
	       "git.autofetch" = true;
	       "git.defaultBranchName" = "master";
	       "python.languageServer" = "Pylance";
	       "terminal.integrated.fontFamily" = "'mononoki Nerd Font'";
            };
        };
    };
}
