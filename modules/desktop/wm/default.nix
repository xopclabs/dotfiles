{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.desktop.wm;
    wmPriorities = [ "hyprland" "niri" ];
in {
    imports = [
        ./hyprland/hyprland.nix
        ./niri/niri.nix
        ./kanshi.nix
        ./hypridle.nix
        ./scripts/scripts.nix
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