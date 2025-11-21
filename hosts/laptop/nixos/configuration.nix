{ config, pkgs, inputs, ... }:

{
    imports = [
        ../../metadata.nix
        ../metadata.nix
        
        ./system.nix
        ./user.nix
        ./network.nix
        ./bluetooth.nix
        ./audio.nix
        ./security.nix
        ./gui.nix
        ./disko.nix
        ./btrfs.nix

        ./programs.nix
    ];
}
