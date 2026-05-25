{ inputs, pkgs, lib, config, ... }:

with lib;
let
    cfg = config.modules.other.minecraft;

    # PrismLauncher-Cracked still references the removed Qt5 extra-cmake-modules alias.
    pkgsWithEcm = pkgs.extend (final: prev: {
        extra-cmake-modules = prev.kdePackages.extra-cmake-modules;
    });

    prismPkgs = pkgsWithEcm.extend inputs.prismlauncher.overlays.default;

    prismlauncher = prismPkgs.prismlauncher.override {
        prismlauncher-unwrapped = prismPkgs.prismlauncher-unwrapped.overrideAttrs (old: {
            nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.pkg-config ];
        });
        additionalPrograms = [ pkgs.ffmpeg ];
    };
in {
    options.modules.other.minecraft = { enable = mkEnableOption "minecraft"; };
    config = mkIf cfg.enable {
        home.packages = [ prismlauncher ];
    };
}
