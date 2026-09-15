{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.desktop.wm;
    wmPriorities = [ "niri" "hyprland" ];
in {
    imports = [
        ./hyprland/hyprland.nix
        ./niri/niri.nix
        ./kanshi.nix
        ./gamma.nix
        ./hypridle.nix
        ./scripts/scripts.nix
        ./wallpaper-rotate
    ];
    
    options.modules.desktop.wm = {
        default = mkOption {
            type = types.nullOr (types.enum wmPriorities);
            default = null;
            internal = true;
        };

        monitorPlacement = {
            enable = mkEnableOption "dynamic monitor placement from hardware metadata" // { default = true; };
            primaryStrategy = mkOption {
                type = types.enum [ "largest-resolution" "largest-physical" ];
                default = "largest-resolution";
                description = "How to choose a primary monitor when no connected monitor has metadata.primary = true.";
            };
            defaultAlign = mkOption {
                type = types.enum [ "center" "start" "end" ];
                default = "center";
                description = "Default alignment for dynamically placed monitors.";
            };
        };
    };
    
    config = mkMerge [
        {
            modules.desktop.wm.default = utils.selectDefault {
                inherit cfg;
                priorities = wmPriorities;
            };
            programs.zsh.shellAliases = mkIf (config.modules.desktop.wm.default != null) {
                startx = config.modules.desktop.wm.default;
            };
        }
        (mkIf (cfg.hyprland.enable || cfg.niri.enable) {
            home.pointerCursor = {
                name = "OpenZone_Black";
                package = pkgs.openzone-cursors;
                size = 24;
                gtk.enable = true;
            };
            home.file.".config/wallpaper" = {
                recursive = true;
                source = ./wallpaper;
            };
        })
    ];
}
