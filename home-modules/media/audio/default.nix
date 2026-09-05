{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.media.audio;
    audioPlayersPriorities = [ "feishin" "kew" ];
in {
    imports = [
        ./feishin.nix
        ./kew.nix
    ];

    options.modules.media.audio = {
        default = mkOption {
            type = types.nullOr (types.enum audioPlayersPriorities);
            default = null;
            internal = true;
        };
    };

    config = {
        modules.media.audio.default = utils.selectDefault {
            inherit cfg;
            priorities = audioPlayersPriorities;
        };
    };
}
