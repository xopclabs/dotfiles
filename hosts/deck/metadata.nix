{ ... }:

{
    imports = [
        ../metadata.nix
    ];

    metadata = {
        user = "xopc";
        hostName = "deck";
        
        hardware = {
            monitors = {
                internal = {
                    name = "Valve Corporation ANX7530 U 0x00000001";
                    mode = "800x1280@90";
                    scale = 1.0;
                    transform = "270";
                    position = "320,1080";
                };
                external = {
                    name = "AOC 22V2WG5 0x000000BF";
                    mode = "1920x1080@74.97";
                    scale = 1.0;
                    position = "0,0";
                };
            };
        };
    };
}

