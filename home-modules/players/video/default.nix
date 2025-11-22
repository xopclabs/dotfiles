{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.players.video;
    videoPlayersPriorities = [ "mpv" "vlc" ];
in {
    imports = [
        ./mpv/mpv.nix
        ./vlc.nix
    ];
    
    options.modules.players.video = {
        default = mkOption {
            type = types.nullOr (types.enum videoPlayersPriorities);
            default = null;
            internal = true;
        };
    };
    
    config = {
        modules.players.video.default = utils.selectDefault {
            inherit cfg;
            priorities = videoPlayersPriorities;
        };
    };
}