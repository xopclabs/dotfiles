{ config, lib, ... }:

with lib;
let
    cfg = config.desktop.adb;
in
{
    options.desktop.adb = {
        enable = mkEnableOption "ADB with wireless debugging discovery";

        mdnsInterfaces = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Interfaces on which to allow incoming mDNS for wireless ADB discovery";
        };
    };

    config = mkIf cfg.enable {
        # The source-built android-tools disables mDNS. Use Google's ADB/fastboot,
        # keeping the other utilities and covering scrcpy's embedded ADB dependency.
        nixpkgs.overlays = [
            (final: prev: {
                android-tools = final.symlinkJoin {
                    name = "android-tools-mdns";
                    paths = [ prev.android-tools ];
                    postBuild = ''
                        ln -sfn ${final.androidenv.androidPkgs.platform-tools}/bin/adb $out/bin/adb
                        ln -sfn ${final.androidenv.androidPkgs.platform-tools}/bin/fastboot $out/bin/fastboot
                    '';
                };
            })
        ];

        networking.firewall.interfaces = genAttrs cfg.mdnsInterfaces (_: {
            allowedUDPPorts = [ 5353 ];
        });
    };
}
