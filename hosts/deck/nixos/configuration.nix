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
        ./proxy.nix

        ./programs
    ];
}
