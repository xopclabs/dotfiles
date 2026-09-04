{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.desktop.bars;
    barPriorities = [ "noctalia" "waybar" ];
in {
    imports = [
        ./waybar/waybar.nix
        ./noctalia/noctalia.nix
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
        assertions = [{
            assertion = !(cfg.waybar.enable && cfg.noctalia.enable);
            message = "Only one of modules.desktop.bars.waybar and modules.desktop.bars.noctalia can be enabled";
        }];
    };
}
