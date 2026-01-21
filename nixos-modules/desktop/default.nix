{ config, lib, pkgs, inputs, ... }:

{
    imports = [
        ./xray.nix
        ./wireguard.nix
        ./steam.nix
        ./lutris.nix
        ./flatpak.nix
        ./yeetmouse.nix
        ./localsend.nix
        ./p81.nix
    ];
}

