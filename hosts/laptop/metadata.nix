{ ... }:

{
    metadata = {
        user = "xopc";
        hostName = "laptop";

        hardware = {
            monitors = {
                laptop = {
                    name = "BOE 0x06B7";
                    mode = "1920x1080@60";
                    scale = 1.0;
                    internal = true;
                    placement = {
                        relativeTo = "primary";
                        side = "below";
                        align = "start";
                        order = 100;
                    };
                    connectors = [ "eDP-1" ];
                };
                oled = {
                    name = "Woodwind Communications Systems Inc SF13TO demoset-1";
                    mode = "1920x1080@60.00";
                    scale = 1.0;
                    placement = {
                        relativeTo = "primary";
                        side = "right";
                        align = "center";
                    };
                    connectors = [
                        "DP-1"
                        "DP-2"
                        "HDMI-A-1"
                        "HDMI-A-2"
                    ];
                    touch = [ "ilitek-ilitek-tp" ];
                };
            };
        };
    };
}
