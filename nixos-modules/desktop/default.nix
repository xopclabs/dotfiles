{ config, lib, pkgs, inputs, ... }:

{
    imports = [
        ./wireguard.nix
        ./steam.nix
        ./lutris.nix
        ./flatpak.nix
        ./yeetmouse.nix
        ./localsend.nix
        ./p81
        ./virtual_webcam.nix
        ./ereader-relay.nix
    ];
}

