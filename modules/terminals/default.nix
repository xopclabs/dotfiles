{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.terminals;
    programPriorities = [ "kitty" ];
in {
    imports = [
        ./kitty.nix
    ];
    
    options.modules.terminals = {
        default = mkOption {
            type = types.nullOr (types.enum programPriorities);
            default = null;
            internal = true;
        };
    };
    
    config = {
        modules.terminals.default = utils.selectDefault {
            inherit cfg;
            priorities = programPriorities;
        };
    };
}