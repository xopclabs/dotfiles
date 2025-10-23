{ config, pkgs, inputs, ... }:

{
    imports = [
        ./disko.nix
        ./system.nix
        ./btrfs.nix
        ./user.nix
        ./network.nix
        ./bluetooth.nix
        ./audio.nix
        ./security.nix
        ./gui.nix
        ./proxy.nix
        ./remote-builds.nix

        ./programs
    ];
}
