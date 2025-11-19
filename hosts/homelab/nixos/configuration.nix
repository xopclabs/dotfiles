{ config, pkgs, inputs, ... }:

{
    imports = [
        ../metadata.nix
        
        ./disko.nix
        ./btrfs.nix
        ./system.nix
        ./user.nix
        ./network.nix
        ./security.nix
	    ./ssh.nix
        ./remote-builds.nix

        ./programs.nix
        ./selfhost.nix
    ];
}
