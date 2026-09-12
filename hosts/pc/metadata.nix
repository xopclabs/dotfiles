{ ... }:

{
    imports = [
        ../metadata.nix
    ];

    metadata = {
        user = "xopc";
        hostName = "pc";
        network.ipv4 = "192.168.1.150";

        hardware.monitors = {
            internal = {
                name = "PNP(HC_) GEM12         0x00A20401";
                mode = "1920x1080@60.00";
                scale = 2.0;
                position = "2560x0";
                connectors = [ "eDP-1" ];
                touch = [ ];
            };
            external = {
                typec = {
                    name = "BOE Display 0x00000001";
                    mode = "2560x1600@144.001";
                    scale = 1.0;
                    position = "0x0";
                    connectors = [
                        "DP-1"
                        "DP-2"
                    ];
                    touch = [ ];
                    variableRefreshRate = false;
                };
                oled = {
                    name = "Woodwind Communications Systems Inc SF13TO demoset-1";
                    mode = "1920x1080@60.00";
                    scale = 1.0;
                    position = "0x0";
                    connectors = [
                        "DP-1"
                        "DP-2"
                        "HDMI-A-1"
                        "HDMI-A-2"
                    ];
                    touch = [
                        "ilitek-ilitek-tp"
                    ];
                };
            };
        };
    };
}
