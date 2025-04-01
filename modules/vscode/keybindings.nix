[
    {
        key = "space t n";
        command = "workbench.action.navigateLeft";
        when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
    }
    {
        key = "space t e";
        command = "workbench.action.navigateDown";
        when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
    }
    {
        key = "space t i";
        command = "workbench.action.navigateUp";
        when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
    }
    {
        key = "space t o";
        command = "workbench.action.navigateRight";
        when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
    }
    {
        key = "space t d";
        command = "workbench.action.closeActiveEditor";
        when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
    }
    {
        key = "space t o";
        command = "workbench.action.closeOtherEditors";
        when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
    }
    {
        key = "space t v";
        command = "workbench.action.splitEditor";
        when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
    }
    {
        key = "space t h";
        command = "workbench.action.splitEditorDown";
        when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
    }
    {
        key = "space t f";
        command = "workbench.action.showAllEditors";
        when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
    }
    {
        key = "space e";
        command = "runCommands";
        args = {
            commands = [
            "workbench.action.toggleSidebarVisibility"
            "workbench.files.action.focusFilesExplorer"
            ];
        };
        when =
            "vim.mode == 'Normal' && (editorTextFocus || !inputFocus) && !sideBarFocus";
    }
    {
        key = "space e";
        command = "runCommands";
        args = {
            commands = [
            "workbench.action.toggleSidebarVisibility"
            "workbench.action.focusActiveEditorGroup"
            ];
        };
        when = "sideBarFocus && !inputFocus";
    }
    {
        key = "space e";
        when = "vim.mode == 'Normal' && editorTextFocus && foldersViewVisible";
        command = "workbench.action.toggleSidebarVisibility";
    }

    # Code Actions
    {
        key = "space c a";
        command = "editor.action.codeAction";
        when = "vim.mode == 'Normal' && editorTextFocus";
    }
    {
        key = "shift-k";
        command = "editor.action.moveLinesUpAction";
        when = "vim.mode == 'VisualLine' && editorTextFocus";
    }
    {
        key = "shift-j";
        command = "editor.action.moveLinesDownAction";
        when = "vim.mode == 'VisualLine' && editorTextFocus";
    }
    {
        key = "shift-k";
        command = "editor.action.showHover";
        when = "vim.mode == 'Normal' && editorTextFocus";
    }
    {
        key = "space c r";
        command = "editor.action.rename";
        when = "vim.mode == 'Normal' && editorTextFocus";
    }
    {
        key = "space c s";
        command = "workbench.action.gotoSymbol";
        when = "vim.mode == 'Normal' && editorTextFocus";
    }
    {
        key = "space space";
        command = "workbench.action.quickOpen";
        when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
    }
    {
        key = "space g d";
        command = "editor.action.revealDefinition";
        when = "vim.mode == 'Normal' && editorTextFocus";
    }
    {
        key = "space g r";
        command = "editor.action.goToReferences";
        when = "vim.mode == 'Normal' && editorTextFocus";
    }
    {
        key = "space g g";
        command = "runCommands";
        when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
        args = { commands = [ "workbench.view.scm" "workbench.scm.focus" ]; };
    }

    # Explorer
    {
        key = "r";
        command = "renameFile";
        when =
            "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
    }
    {
        key = "c";
        command = "filesExplorer.copy";
        when =
            "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
    }
    {
        key = "p";
        command = "filesExplorer.paste";
        when =
            "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
    }
    {
        key = "x";
        command = "filesExplorer.cut";
        when =
            "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
    }
    {
        key = "d";
        command = "deleteFile";
        when =
            "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
    }
    {
        key = "a";
        command = "explorer.newFile";
        when =
            "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
    }
    {
        key = "s";
        command = "explorer.openToSide";
        when =
            "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
    }
    {
        key = "shift-s";
        command = "runCommands";
        when =
            "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
        args = {
            commands = [
            "workbench.action.splitEditorDown"
            "explorer.openAndPassFocus"
            "workbench.action.closeOtherEditors"
            ];
        };
    }
    {
        key = "enter";
        command = "explorer.openAndPassFocus";
        when =
            "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceIsFolder && !inputFocus";
    }
    {
        key = "enter";
        command = "list.toggleExpand";
        when =
            "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && explorerResourceIsFolder && !inputFocus";
    }

    # Debug
    {
        key = "space d a";
        command = "workbench.action.debug.selectandstart";
        when =
            "vim.mode == 'Normal' && (editorTextFocus || !inputFocus) && debuggersAvailable";
    }
    {
        key = "space d t";
        command = "workbench.action.debug.stop";
        when =
            "vim.mode == 'Normal' && editorTextFocus && inDebugMode && !focusedSessionIsAttached";
    }
    {
        key = "space d o";
        command = "workbench.action.debug.stepOver";
        when =
            "vim.mode == 'Normal' && (editorTextFocus || !inputFocus) && inDebugMode && debugState == 'stopped'";
    }
    {
        key = "space d b";
        command = "editor.debug.action.toggleBreakpoint";
        when = "vim.mode == 'Normal' && editorTextFocus";
    }
    {
        key = "space d e";
        command = "editor.debug.action.showDebugHover";
        when =
            "vim.mode == 'Normal' && editorTextFocus && inDebugMode && debugState == 'stopped'";
    }
    {
        key = "space d c";
        command = "workbench.action.debug.continue";
        when =
            "vim.mode == 'Normal' && (editorTextFocus || !inputFocus) && inDebugMode && debugState == 'stopped'";
    }

    # Chat
    {
        key = "space a n";
        command = "composer.newAgentChat";
        when = "vim.mode == 'Normal' && editorTextFocus && !composerBarIsVisible";
    }
    {
        key = "space a a";
        command = "aichat.insertselectionintochat";
        when = "vim.mode == 'Normal' && editorTextFocus && !composerBarIsVisible";
    }
    {
        key = "space a e";
        command = "aipopup.action.modal.generate";
        when = "vim.mode == 'Normal' && editorTextFocus && !composerBarIsVisible";
    }
    {
        key = "space a q";
        command = "aichat.newchataction";
        when = "vim.mode == 'Normal' && editorTextFocus && !composerBarIsVisible";
    }
    {
        key = "ctrl+l";
        command = "-aichat.newchataction";
    }
]
