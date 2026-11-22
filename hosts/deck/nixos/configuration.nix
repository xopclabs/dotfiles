{ config, pkgs, inputs, ... }:

{
    imports = [
        ../metadata.nix
        
        ./disko.nix
        ./system.nix
        ./btrfs.nix
        ./user.nix
        ./network.nix
        ./bluetooth.nix
        ./audio.nix
        ./security.nix
        ./gui.nix
        ./gamescope-panel-idle/gamescope-panel-idle.nix
        ./remote-builds.nix

        ./programs.nix
    ];
}
