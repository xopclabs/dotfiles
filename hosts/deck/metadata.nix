{ ... }:

{
    imports = [
        ../metadata.nix
    ];

    metadata = {
        user = "xopc";
        hostName = "deck";
        network.ipv4 = "192.168.1.151";

        hardware.monitors = {
            deck = {
                name = "Valve Corporation ANX7530 U 0x00000001";
                mode = "800x1280@90";
                scale = 1.0;
                internal = true;
                placement = {
                    relativeTo = "primary";
                    side = "right";
                    align = "center";
                    order = 100;
                };
                connectors = [ "eDP-1" ];
                touch = [
                    "fts3528:00-2808:1015"
                    "fts3528:00-2808:1015-unknown"
                ];
            };
            oled = {
                name = "Woodwind Communications Systems Inc SF13TO demoset-1";
                mode = "1920x1080@60.00";
                scale = 1.0;
                connectors = [ "DP-1" ];
                touch = [
                    "ilitek-ilitek-tp"
                ];
            };
        };
    };
}
