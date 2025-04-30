{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.packages;
in {
    imports = [
        ./common.nix
        ./optional.nix
    ];
}