{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.media.video;
    videoPlayersPriorities = [ "mpv" "vlc" ];
in {
    imports = [
        ./mpv/mpv.nix
        ./vlc.nix
    ];
    
    options.modules.media.video = {
        default = mkOption {
            type = types.nullOr (types.enum videoPlayersPriorities);
            default = null;
            internal = true;
        };
    };
    
    config = {
        modules.media.video.default = utils.selectDefault {
            inherit cfg;
            priorities = videoPlayersPriorities;
        };
    };
}