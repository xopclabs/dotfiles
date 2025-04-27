{ config, lib, pkgs, ... }:

{
    # Environment variables
    home = {
        sessionVariables = {
            NH_FLAKE = "$HOME/dotfiles";
        };
        packages = with pkgs; [
            uv
        ];
    };

    # Make non-nix packages work
    targets.genericLinux.enable = true;
    # Let home-manager manage itself
    programs.home-manager.enable = true;
    
} 
