{ config, lib, ... }:

{
    # Environment variables
    home = {
        sessionVariables = {
            FLAKE = "$HOME/dotfiles";
        };
    };

    # Make non-nix packages work
    targets.genericLinux.enable = true;
    # Let home-manager manage itself
    programs.home-manager.enable = true;
    
} 
