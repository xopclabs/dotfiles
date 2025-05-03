{ config, pkgs, inputs, ... }:

{
    imports = [
        ./system.nix
        ./user.nix
        ./network.nix
        ./bluetooth.nix
        ./audio.nix
        ./security.nix
        ./gui.nix
        ./vpn.nix
        ./steam.nix
    ];
}
