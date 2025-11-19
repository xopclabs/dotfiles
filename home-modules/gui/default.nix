{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.gui;
in {
    imports = [
        ./flameshot.nix
        ./wl-kbptr.nix
    ];
}
