{ config, lib, pkgs, inputs, ... }:

{
    imports = [
        ./xray.nix
        ./singbox.nix
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

