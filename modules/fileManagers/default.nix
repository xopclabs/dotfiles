{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.fileManagers;
    fileManagerPrioritiesGui = [ "nautilus" ];
    fileManagerPrioritiesTui = [ "yazi" "ranger" ];
in {
    imports = [
        ./yazi.nix
        ./ranger.nix
        ./nautilus.nix
    ];
    
    options.modules.fileManagers = {
        default = mkOption {
            type = types.nullOr (types.enum fileManagerPrioritiesTui);
            default = null;
            internal = true;
        };
        gui = mkOption {
            type = types.nullOr (types.enum fileManagerPrioritiesGui);
            default = null;
            internal = true;
        };
    };
    
    config = {
        modules.fileManagers.default = utils.selectDefault {
            inherit cfg;
            priorities = fileManagerPriorities;
        };
        modules.fileManagers.gui = utils.selectDefault {
            inherit cfg;
            priorities = fileManagerPrioritiesGui;
        };
    };
}