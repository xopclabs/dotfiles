{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.cli;
    shellPriorities = [ "zsh" ];
in {
    imports = [
        ./bat.nix
        ./eza.nix
        ./fzf.nix
        ./starship.nix
        ./tmux.nix
        ./zoxide.nix
        ./zsh.nix
    ];
    
    options.modules.cli = {
        shell = mkOption {
            type = types.nullOr (types.enum shellPriorities);
            default = null;
            internal = true;
        };
    };
    
    config = {
        modules.cli.shell = utils.selectDefault {
            inherit cfg;
            priorities = shellPriorities;
        };
    };
}
