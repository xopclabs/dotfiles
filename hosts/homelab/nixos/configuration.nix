{ config, pkgs, inputs, ... }:

{
    imports = [
        ./disko.nix
        ./btrfs.nix
        ./system.nix
        ./user.nix
        ./network.nix
        ./security.nix
        ./proxy.nix
    ];
}
