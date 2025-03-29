{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.mpv;
in {
    options.modules.mpv = { enable = mkEnableOption "mpv"; };
    config = mkIf cfg.enable {
        programs.mpv = {
            enable = true;
            bindings = {
                "Shift+Left"  = "playlist-prev";
                "Shift+Right"  = "playlist-next";
            };
            config = {
                loop-file = "inf";
                cache = "yes";
                cache-secs = 300;
                cache-on-disk = "yes";
                demuxer-cache-dir = "${config.xdg.configHome}/.cache/mpv";
            };
        };
    };
}
