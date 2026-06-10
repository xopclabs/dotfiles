{ config, lib, inputs, ... }:

{
    imports = [ 
        ../../../nixos-modules/desktop/default.nix
    ];
    
    config.desktop = {
        singbox = {
            enable = true;
            outbounds = {
                wg = {
                    enable = true;
                    bindInterface = "wg-vps";
                    bindAddress = "10.13.13.2";
                };
                xray.subscriptions = {
                    alpha = true;
                    beta = true;
                };
            };
            proxychains = {
                enable = true;
                port = 10808;
            };
        };
    };
}
