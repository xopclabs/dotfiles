{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.desktop.launchers;
    launcherPriorities = [ "tofi" "rofi" ];
in {
    imports = [
        ./rofi/rofi.nix
        ./tofi.nix
    ];
    
    options.modules.desktop.launchers = {
        default = mkOption {
            type = types.nullOr (types.enum launcherPriorities);
            default = null;
            internal = true;
        };
    };
    
    config = {
        modules.desktop.launchers.default = utils.selectDefault {
            inherit cfg;
            priorities = launcherPriorities;
        };
    };
}