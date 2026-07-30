{ ... }:

{
    imports = [
        ../metadata.nix
    ];

    metadata = {
        user = "xopc";
        hostName = "deck";
        
        hardware.monitors = {
            internal = {
                name = "Valve Corporation ANX7530 U 0x00000001";
                mode = "800x1280@90";
                scale = 1.0;
                transform = "270";
                # to the right of external
                position = "1920x140";
                # below external
                # position = "320x1080";
                connector = "eDP-1";
                touch = [
                    "fts3528:00-2808:1015"
                    "fts3528:00-2808:1015-unknown"
                ];
            };
            external = {
                oled = {
                    name = "Woodwind Communications Systems Inc SF13TO demoset-1";
                    mode = "1920x1080@60.00";
                    scale = 1.0;
                    position = "0x0";
                    # Absolute-mouse sibling ignored via udev on this host.
                    connector = "DP-1";
                    touch = [
                        "ilitek-ilitek-tp"
                    ];
                };
            };
        };
    };
}
