{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.media;
in {
    imports = [
        ./video
        ./audio
    ];
}
