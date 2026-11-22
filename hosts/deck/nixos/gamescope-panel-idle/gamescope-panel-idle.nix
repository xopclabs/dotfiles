{ pkgs, ... }:

{
    systemd.user.services.gamescope-panel-idle = {
        description = "Power off the internal panel when Gaming Mode is idle";
        partOf = [ "gamescope-session.target" ];
        bindsTo = [ "gamescope-session.service" ];
        after = [ "gamescope-session.service" ];
        wantedBy = [ "gamescope-session.target" ];
        environment = {
            GAMESCOPE_WAYLAND_DISPLAY = "gamescope-0";
            PANEL_IDLE_SECONDS = "180";
        };
        serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 ${./gamescope-panel-idle.py}";
    };
}
