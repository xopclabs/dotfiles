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
        ./proxy.nix
	    ./ssh.nix
        ./remote-builds.nix

        ./services.nix
    ];
}
