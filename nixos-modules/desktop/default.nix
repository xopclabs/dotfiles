{ config, lib, pkgs, inputs, ... }:

{
    imports = [
        ./xray.nix
        ./steam.nix
        ./lutris.nix
        ./flatpak.nix
        ./yeetmouse.nix
        ./localsend.nix
    ];
}

