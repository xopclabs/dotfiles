{ ... }:

{
    imports = [
        ../metadata.nix
    ];

    metadata = {
        user = "xopc";
        hostName = "pc";

        hardware.monitors = {
            # Built-in 5" panel. Connector/name are placeholders until we inspect
            # `niri msg outputs`/`hyprctl monitors` on the machine.
            internal = {
                name = "Built-in 5 inch panel";
                mode = "1920x1080@60.00";
                scale = 2.0;
                position = "1920x0";
                connector = "eDP-1";
                touch = [ ];
            };
            external = {
                oled = {
                    name = "Woodwind Communications Systems Inc SF13TO demoset-1";
                    mode = "1920x1080@60.00";
                    scale = 1.0;
                    position = "0x0";
                    connector = "DP-1";
                    touch = [
                        "ilitek-ilitek-tp"
                    ];
                };
            };
        };
    };
}
