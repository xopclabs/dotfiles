{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.gui;
in {
    imports = [
        ./dunst.nix
        ./flameshot.nix
        ./gtk.nix
        ./kicad.nix
        ./kitty.nix
        ./plover.nix
    ];
}
