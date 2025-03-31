{ config, lib, ... }:

with lib;
let 
    cfg = config.modules.vscode;
in {
    config.programs.vscode.profiles.default.userSettings = mkIf cfg.enable {
        editor.fontSize = 20;
        editor.fontFamily = "'Mononoki Nerd Font','Monaco','Droid Sans Mono', 'monospace', monospace";
        editor.minimap.enabled = false;
        telemetry.telemetryLevel = "off";
        explorer.confirmDragAndDrop = false;
        git.confirmSync = false;
        explorer.confirmDelete = false;
        dev.containers.copyGitConfig = true;
        notebook.cellToolbarLocation = {
            "default" = "right";
            "jupyter-notebook" = "right";
        };
        editor.inlineSuggest.enabled = true;
        editor.suggestSelection = "first";
        editor.tabSize = 4;
        editor.wordWrap = "off";
        git.autofetch = true;
        git.defaultBranchName = "main";
        python.languageServer = "Pylance";
        terminal.integrated.fontFamily = "'mononoki Nerd Font'";
        remote.autoForwardPortsSource = "hybrid";
        jupyter.widgetScriptSources = [
            "jsdelivr.com"
            "unpkg.com"
        ];
        jupyter.askForKernelRestart = false;

        vim.easymotion = true;
        files.exclude = {
            "**/__pycache__" = true;
            "**/.ipynb_checkpoints" = true;
        };
        search.exclude = {
            "**/__pycache__" = true;
            "**/.ipynb_checkpoints" = true;
            "**/node_modules" = true;
            "**/build" = true;
        };
        window.titleBarStyle = "custom";
        editor.codeLensFontFamily = "'Monaco'";
        terminal.integrated.fontSize = 16;
        chat.editor.fontSize = 16;
        workbench.activityBar.orientation = "vertical";
        window.customTitleBarVisibility = "auto";
        files.autoSave = "onFocusChange";
        workbench.colorTheme = "Nord";
    };
}