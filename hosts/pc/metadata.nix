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
            # Built-in 5" panel. Connector/name are placeholders until we inspect
            # `niri msg outputs`/`hyprctl monitors` on the machine.
            internal = {
                name = "Built-in 5 inch panel";
                mode = "1920x1080@60.00";
                scale = 2.0;
                position = "1920x0";
                connectors = [ "eDP-1" ];
                touch = [ ];
            };
            external = {
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
