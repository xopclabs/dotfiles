{ config, lib, inputs, ... }:

{
    imports = [ 
        ../../../nixos-modules/desktop/default.nix
    ];
    
    config.desktop = {
        singbox = {
            enable = true;
            outbounds.xray.subscriptions = {
                alpha = true;
                beta = true;
            };
            proxychains = {
                enable = true;
                port = 10808;
            };
        };
    };
}
