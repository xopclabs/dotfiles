{ config, pkgs, inputs, ... }:

{
    imports = [
        ../../metadata.nix
        ../metadata.nix
        
        ./system.nix
        ./user.nix
        ./network.nix
        ./bluetooth.nix
        ./security.nix
        ./disko.nix
        ./hardware-configuration.nix
        ./btrfs.nix
        ./ssh.nix

        ./programs.nix
    ];
}
