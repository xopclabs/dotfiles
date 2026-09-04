{ lib, config, ... }:

with lib;
let
    cfg = config.modules.desktop.bars.waybar;
    icons = import ../app-icons.nix { inherit lib; };
in {
    config = mkIf cfg.enable {
        programs.waybar = {
            settings.mainBar = {
                "hyprland/workspaces" = {
                    window-rewrite-default = icons.defaultNerd;
                    window-rewrite = icons.windowRewrite;
                };
                "niri/workspaces" = {
                    window-rewrite-default = icons.defaultNerd;
                    window-rewrite = icons.niriWindowRewrite;
                };
            };
        };
    };
}
