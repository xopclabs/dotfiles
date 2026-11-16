{ pkgs, lib, config, ... }:

let
    cfg = config.modules.media.ffmpeg;
    settings = pkgs.writeText "ffmpeghw.json" (builtins.toJSON {
        ffmpeg = "${pkgs.ffmpeg}/bin/ffmpeg";
        ffprobe = "${pkgs.ffmpeg}/bin/ffprobe";
        vainfo = "${pkgs.libva-utils}/bin/vainfo";
        inherit (cfg.acceleration) igpu egpu;
    });
    wrapper = pkgs.writeShellApplication {
        name = "ffmpeghw";
        text = ''
            exec ${pkgs.python3}/bin/python3 ${./ffmpeghw.py} ${settings} "$@"
        '';
    };
in {
    options.modules.media.ffmpeg = {
        enable = lib.mkEnableOption "FFmpeg";
        acceleration = {
            enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Install ffmpeghw alongside unmodified FFmpeg.";
            };
            igpu = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                example = "0000:c8:00.0";
                description = "Integrated GPU PCI address or DRM render-device path; a single available GPU is detected automatically.";
            };
            egpu = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                example = "0000:03:00.0";
                description = "External GPU PCI address or DRM render-device path; an unavailable GPU falls back to the other configured GPU.";
            };
        };
    };

    config = lib.mkIf cfg.enable {
        home.packages = [ pkgs.ffmpeg ]
            ++ lib.optional cfg.acceleration.enable wrapper;
    };
}
