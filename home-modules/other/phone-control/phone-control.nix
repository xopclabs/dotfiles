{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.modules.other.phoneControl;
    phoneControl = pkgs.writeShellApplication {
        name = "phone-control";
        runtimeInputs = [
            pkgs.android-tools
            pkgs.scrcpy
            pkgs.libnotify
            pkgs.coreutils
            pkgs.gawk
            pkgs.util-linux
            pkgs.jq
        ] ++ lib.optionals config.modules.desktop.wm.niri.enable [
            config.programs.niri.package
        ] ++ lib.optionals cfg.notifications.enable [
            pkgs.python3
        ];
        text = ''
            pin_file=${escapeShellArg (if cfg.autoUnlock then config.sops.secrets."phone-control/pin".path else "")}
            relay_provision=${escapeShellArg (if cfg.notifications.enable then "${./provision.py}" else "")}
            relay_port=${toString cfg.notifications.port}
        '' + builtins.readFile ./phone-control.sh;
    };
in
{
    options.modules.other.phoneControl = {
        enable = mkEnableOption "wireless scrcpy phone-control launcher (requires ADB with mDNS support)";

        autoUnlock = mkEnableOption "unlock the selected phone using the phone-control/pin sops secret before opening scrcpy";
    };

    config = mkIf cfg.enable {
        sops.secrets."phone-control/pin" = mkIf cfg.autoUnlock {
            mode = "0400";
            path = "${config.xdg.configHome}/phone-control/pin";
        };

        programs.niri.settings.window-rules = mkIf config.modules.desktop.wm.niri.enable [
            {
                matches = [ { app-id = "^phone-control$"; title = "^Phone Control$"; } ];
                default-column-width = { fixed = 499; };
            }
        ];

        home.packages = [ phoneControl ];
        xdg.desktopEntries.phone-control = {
            name = "Phone Control";
            comment = "Control your paired phone over Wi-Fi with its screen off";
            icon = "smartphone";
            exec = "${phoneControl}/bin/phone-control";
            terminal = false;
            categories = [ "Utility" "RemoteAccess" ];
        };
    };
}
