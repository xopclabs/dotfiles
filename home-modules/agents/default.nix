{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.agents;
in {
    imports = [
        ./pi.nix
    ];
}
