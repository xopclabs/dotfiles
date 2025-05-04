{ config, pkgs, inputs, ... }:

{
    imports = [
        ./disko.nix
        ./system.nix
        ./user.nix
        ./network.nix
        ./security.nix
        ./vpn.nix
    ];
}
