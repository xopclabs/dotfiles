{ ... }:

{
    metadata = {
        user = "xopc";
        hostName = "laptop";

        network = {
            ipv4 = "192.168.254.100";
            defaultGateway = "192.168.254.1";
        };

        selfhost = {
            mainIpv4 = "192.168.254.10";
        };
        
        hardware = {
            monitors = {
                internal = {
                    name = "BOE 0x06B7";
                    mode = "1920x1080@60";
                    scale = 1.0;
                    position = "0x1080";
                };
                external = {
                    name = "AOC 22V2WG5 0x000000BF";
                    mode = "1920x1080@74.97";
                    scale = 1.0;
                    position = "0x0";
                };
            };
        };
    };
}

