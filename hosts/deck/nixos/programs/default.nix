{ config, pkgs, inputs, ... }:

{
    imports = [
        ./steam.nix
        ./lutris.nix
        ./flatpak.nix
    ];
}
