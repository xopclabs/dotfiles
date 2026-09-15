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
            unknown = {
                include = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Whether dynamic placement should also move outputs not declared in metadata.hardware.monitors.";
                };
                primaryEligible = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Whether unknown outputs can become primary when no metadata.primary output is connected.";
                };
                placement = {
                    relativeTo = mkOption {
                        type = types.enum [ "primary" ];
                        default = "primary";
                        description = "Anchor monitor for unknown-output placement.";
                    };
                    side = mkOption {
                        type = types.enum [ "left" "right" "above" "below" "same" ];
                        default = "right";
                        description = "Side of the primary where unknown outputs should be placed.";
                    };
                    align = mkOption {
                        type = types.enum [ "center" "start" "end" ];
                        default = "center";
                        description = "Alignment for unknown outputs.";
                    };
                    offsetFraction = mkOption {
                        type = types.listOf (types.oneOf [ types.float types.int ]);
                        default = [ 0.0 0.0 ];
                        description = "Additional unknown-output x/y offset as fractions of the primary logical size.";
                    };
                    stack = mkOption {
                        type = types.enum [ "horizontal" "vertical" "none" ];
                        default = "horizontal";
                        description = "How unknown outputs stack with other outputs on the same side.";
                    };
                    order = mkOption {
                        type = types.int;
                        default = 50;
                        description = "Unknown-output stack order.";
                    };
                };
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
