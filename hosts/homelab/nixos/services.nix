{ config, lib, inputs, ... }:

{
    imports = [ 
        ../../../services/default.nix
    ];
    
    config.services.homelab = {
        ddns.enable = true;

        pihole_unbound.enable = true;
        
        wireguard = {
            enable = true;
            listenPort = 51820;
            serverIP = "10.250.250.1/24";
            subnet = "10.250.250.0/24";
            externalInterface = "ens18";
            peers = {
                vps = {
                    publicKey = "HK4EezS2UTm64clhYLBa4QHAN/0ad/eyfv14N2ffnyA=";
                    allowedIPs = [ "10.250.250.2/32" ];
                };
                pavel = {
                    publicKey = "h/zTkj0tEVTYjJYZ3mvNLBblkKD9XMq7UpR03dlWSxo=";
                    allowedIPs = [ "10.250.250.3/32" ];
                };
                pavel-pc = {
                    publicKey = "dgkPzUZ+R3ODZWzY46DROU7VOOvuvndJucQlWEu0UV0=";
                    allowedIPs = [ "10.250.250.4/32" ];
                };
                wife-pc = {
                    publicKey = "cujVQ6lmprG+mszcD5GmzZK/Cgn5rwXMGh+rp1Qasmo=";
                    allowedIPs = [ "10.250.250.5/32" ];
                };
                extra = {
                    publicKey = "89c8JEfe/ezs8OwC8aeTeJcJqj6Ew569xw87Wvs1jSs=";
                    allowedIPs = [ "10.250.250.101/32" ];
                };
            };
        };

        minecraft = {
            enable = true;
            distantHorizons.enable = true;
            beta.enable = false;
        };
    };
}
