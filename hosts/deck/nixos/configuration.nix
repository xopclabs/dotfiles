{ config, pkgs, inputs, ... }:

{
    imports = [
        ../../metadata.nix
        ../metadata.nix
        
        ./disko.nix
        ./system.nix
        ./btrfs.nix
        ./user.nix
        ./network.nix
        ./bluetooth.nix
        ./audio.nix
        ./security.nix
        ./gui.nix
        ./proxy.nix
        ./remote-builds.nix

        ./programs
    ];
}
