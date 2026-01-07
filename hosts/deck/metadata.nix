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
                position = "1920,140";
            };
            external = {
                oled = {
                    name = "Woodwind Communications Systems Inc SF13TO demoset-1";
                    mode = "1920x1080@60.00";
                    scale = 1.0;
                    position = "0,0";
                };
            };
        };
    };
}

