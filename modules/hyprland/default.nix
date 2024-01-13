{ nputs, pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.hyprland;

in {
    options.modules.hyprland= { enable = mkEnableOption "hyprland"; };
    config = lib.mkIf cfg.enable {
        home.packages = with pkgs; [
            wofi swaybg swaylock swayidle xwayland wlsunset wl-clipboard hyprland

        ];
        programs.zsh.shellAliases = { startx = "Hyprland"; };
        # Swayidle
        services.swayidle = {
            enable = true;
            systemdTarget = "hyprland-session.target";
            events = [
                { event = "before-sleep"; command = "${pkgs.swaylock}/bin/swaylock -f"; }
            ];
            timeouts = [
                { timeout = 1; command = "${pkgs.libnotify}/bin/notify-send 'test'"; }
                { timeout = 180; command = "${pkgs.swaylock}/bin/swaylock -f"; }
                { timeout = 600; command = "${pkgs.systemd}/bin/systemctl suspend"; }
            ];
        };

        home.file.".config/hypr/hyprland.conf".source = ./hyprland.conf;
    };
}
