{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.desktop.wm;
    wmPriorities = [ "hyprland" "niri" ];
in {
    imports = [
        ./hyprland/hyprland.nix
        ./niri/niri.nix
        ./kanshi.nix
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
