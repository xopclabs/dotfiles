{ config, lib, inputs, ... }:

{
    imports = [ 
        ../../../nixos-modules/desktop/default.nix
    ];
    
    config.desktop = {
        xray = {
            enable = false;
            proxychains = {
                enable = true;
                port = 10808;
            };
        };
    };
}

