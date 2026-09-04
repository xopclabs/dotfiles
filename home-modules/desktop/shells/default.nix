{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.desktop.shells;
    shellPriorities = [ "noctalia" ];
in {
    imports = [
        ./noctalia/noctalia.nix
    ];

    options.modules.desktop.shells = {
        default = mkOption {
            type = types.nullOr (types.enum shellPriorities);
            default = null;
            internal = true;
        };
    };

    config = {
        modules.desktop.shells.default = utils.selectDefault {
            inherit cfg;
            priorities = shellPriorities;
        };
    };
}
