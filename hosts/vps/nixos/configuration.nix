{ config, pkgs, inputs, ... }:

{
    imports = [
        ../metadata.nix
        ./hardware-configuration.nix
        
        ./disko.nix
        ./btrfs.nix
        ./system.nix
        ./user.nix
        ./network.nix
        ./security.nix
	    ./ssh.nix

        ./selfhost.nix
    ];
}
