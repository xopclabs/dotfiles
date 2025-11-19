{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.editors;
    editorPrioritiesGui = [ "vscode" "cursor" ];
    editorPrioritiesTui = [ "nvim" ];
in {
    imports = [
        ./vscode/vscode.nix
        ./nvim/nvim.nix
    ];
    
    options.modules.editors = {
        default = mkOption {
            type = types.nullOr (types.enum editorPrioritiesTui);
            default = null;
            internal = true;
        };
        gui = mkOption {
            type = types.nullOr (types.enum editorPrioritiesGui);
            default = null;
            internal = true;
        };
    };
    
    config = {
        modules.editors.default = utils.selectDefault {
            inherit cfg;
            priorities = editorPrioritiesTui;
        };
        modules.editors.gui = utils.selectDefault {
            inherit cfg;
            priorities = editorPrioritiesGui;
        };
    };
}
