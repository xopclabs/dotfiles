{ config, pkgs, inputs, ... }:

{
    imports = [
        ./system.nix
        ./user.nix
        ./wireless.nix
        ./audio.nix
        ./security.nix
        ./gui.nix
        ./vpn.nix
    ];
}
