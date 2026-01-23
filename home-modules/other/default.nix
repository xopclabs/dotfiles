{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.other;
in {
    imports = [
        ./kicad.nix
        ./plover.nix
        ./minecraft.nix
        ./androidcam.nix
    ];
}
