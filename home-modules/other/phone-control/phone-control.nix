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
        ];
        text = ''
            expected_serial=${escapeShellArg (if cfg.deviceSerial == null then "" else cfg.deviceSerial)}
            pin_file=${escapeShellArg (if cfg.autoUnlock then config.sops.secrets."phone-control/pin".path else "")}
        '' + builtins.readFile ./phone-control.sh;
    };
in
{
    options.modules.other.phoneControl = {
        enable = mkEnableOption "wireless scrcpy phone-control launcher (requires ADB with mDNS support)";

        deviceSerial = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Phone's ro.serialno; required for automatic unlock, independent of Wi-Fi IP and port";
        };

        autoUnlock = mkEnableOption "unlock the selected phone using the phone-control/pin sops secret before opening scrcpy";
    };

    config = mkIf cfg.enable {
        assertions = [
            {
                assertion = !cfg.autoUnlock || (cfg.deviceSerial != null && cfg.deviceSerial != "");
                message = "Phone Control automatic unlock requires deviceSerial to prevent sending the PIN to another phone.";
            }
        ];

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
