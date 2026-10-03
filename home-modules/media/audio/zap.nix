args@{ config, lib, ... }:

with lib;
let
    zap = args.zap or null;
    cfg = config.modules.media.audio.zap;
in {
    imports = optional (zap != null) zap.homeManagerModules.default;

    options.modules.media.audio.zap = {
        enable = mkEnableOption "zap music player";
        popupOutput = mkOption {
            type = types.str;
            default = "focused";
            description = "Focused output or connector used by the zap picker.";
        };
        settings = mkOption {
            type = types.attrs;
            default = {};
            description = "User-facing zap settings, validated by the upstream module.";
        };
        sessionTarget = mkOption {
            type = types.str;
            default = "nixos-fake-graphical-session.target";
            description = "This host's target started after Niri imports its graphical environment.";
        };
    };

    config = optionalAttrs (zap != null) (mkIf cfg.enable {
        programs.zap = {
            enable = true;
            settings = recursiveUpdate {
                popup.output = cfg.popupOutput;
            } cfg.settings;
            ui.sessionTarget = cfg.sessionTarget;
        };
    });
}
