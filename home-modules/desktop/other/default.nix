{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.desktop.other;
in {
    imports = [
        ./dunst.nix
        ./gtk.nix
        ./xdg.nix
    ];
}