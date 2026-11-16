{ pkgs, lib, config, ... }:

let
    cfg = config.modules.media.ffmpeg;
    settings = pkgs.writeText "ffmpeghw.json" (builtins.toJSON {
        ffmpeg = "${pkgs.ffmpeg}/bin/ffmpeg";
        ffprobe = "${pkgs.ffmpeg}/bin/ffprobe";
        vainfo = if cfg.acceleration.type == "vaapi"
            then "${pkgs.libva-utils}/bin/vainfo" else null;
        inherit (cfg.acceleration) type cudaDevice igpu egpu;
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
            type = lib.mkOption {
                type = lib.types.enum [ "vaapi" "cuda" ];
                default = "vaapi";
                description = "Acceleration backend: VA-API for AMD/Intel, or CUDA decoding and NVENC encoding for NVIDIA.";
            };
            cudaDevice = lib.mkOption {
                type = lib.types.ints.unsigned;
                default = 0;
                description = "CUDA device ordinal used by the cuda backend.";
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
