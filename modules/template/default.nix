{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.MODULEGROUP;
    programPriorities = [ "PROGRAM" ];
in {
    imports = [
        ./PROGRAM.nix
    ];
    
    options.modules.MODULEGROUP = {
        default = mkOption {
            type = types.nullOr (types.enum programPriorities);
            default = null;
            internal = true;
        };
    };
    
    config = {
        modules.MODULEGROUP.default = utils.selectDefault {
            inherit cfg;
            priorities = programPriorities;
        };
    };
}