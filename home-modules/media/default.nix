{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.media;
in {
    imports = [
        ./ffmpeg/ffmpeg.nix
        ./video
        ./audio
    ];
}
