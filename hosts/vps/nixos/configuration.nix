{ config, pkgs, inputs, ... }:

{
    imports = [
        ../../metadata.nix
        ../metadata.nix
        
        ./disko.nix
        ./btrfs.nix
        ./system.nix
        ./user.nix
        ./network.nix
        ./security.nix
	    ./ssh.nix

        ./services.nix
    ];
}
