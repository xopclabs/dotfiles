{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.desktop.bars;
    barPriorities = [ "waybar" ];
in {
    imports = [
        ./waybar/waybar.nix
    ];
    
    options.modules.desktop.bars = {
        default = mkOption {
            type = types.nullOr (types.enum barPriorities);
            default = null;
            internal = true;
        };
    };
    
    config = {
        modules.desktop.bars.default = utils.selectDefault {
            inherit cfg;
            priorities = barPriorities;
        };
    };
}