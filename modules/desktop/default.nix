{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.desktop;
in {
    imports = [
        ./wm
        ./bars
        ./launchers
        ./other
    ];
}