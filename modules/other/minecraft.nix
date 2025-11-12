{ inputs, pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.other.minecraft;
in {
    options.modules.other.minecraft = { enable = mkEnableOption "minecraft"; };
    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            (inputs.prismlauncher.packages.${pkgs.system}.prismlauncher.override {
                additionalPrograms = [ ffmpeg ];
            })
        ];
    };
}
