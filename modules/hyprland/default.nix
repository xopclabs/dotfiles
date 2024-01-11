{ inputs, pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.hyprland;

in {
    options.modules.hyprland= { enable = mkEnableOption "hyprland"; };
    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            wofi swaybg swaylock xwayland wlsunset wl-clipboard hyprland
        ];
        programs.zsh.shellAliases = { startx = "Hyprland"; };

        # Swayidle
        services.swayidle = {
            enable = true;
            events = [
                { event = "before-sleep"; command = "${pkgs.swaylock}/bin/swaylock"; }
            ];
            timeouts = [
                { timeout = 300; command = "${pkgs.swaylock}/bin/swaylock -fF"; }
            ];
        };

        home.file.".config/hypr/hyprland.conf".source = ./hyprland.conf;
    };
}
