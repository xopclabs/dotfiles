{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.players;
in {
    imports = [
        ./video
    ];
}