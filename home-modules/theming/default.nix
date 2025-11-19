{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.theming;
in {
    imports = [
        ./stylix.nix
    ];
}