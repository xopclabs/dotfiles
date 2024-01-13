{ pkgs, config, ... }: 
{
    # Swayidle
    services.swayidle = {
        enable = true;
        events = [
            { event = "before-sleep"; command = "${pkgs.swaylock}/bin/swaylock"; }
        ];
        timeouts = [
            { timeout = 1; command = "${pkgs.libnotify}/bin/notify-send 'testing'"; }
            { timeout = 60; command = "${pkgs.swaylock}/bin/swaylock -f"; }
            { timeout = 1200; command = "${pkgs.systemd}/bin/systemctl hibernate"; }
        ];
    };
}
