{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.desktop.wm;
    wmPriorities = [ "hyprland" ];
in {
    imports = [
        ./hyprland/hyprland.nix
        ./kanshi.nix
        ./hypridle.nix
    ];
    
    options.modules.desktop.wm = {
        default = mkOption {
            type = types.nullOr (types.enum wmPriorities);
            default = null;
            internal = true;
        };
    };
    
    config = {
        modules.desktop.wm.default = utils.selectDefault {
            inherit cfg;
            priorities = wmPriorities;
        };
    };
}