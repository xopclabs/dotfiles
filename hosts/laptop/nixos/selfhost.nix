{ config, lib, inputs, ... }:

{
    imports = [ 
        ../../../nixos-modules/selfhost/default.nix
    ];
    
    config.homelab = {
        pihole_unbound = {
            enable = true;
            pihole = {
                firewall = {
                    dns = true;
                    dhcp = true;
                    webserver = true;
                };
            };
            unbound.forwardUpstream = true;
        };

        # VPN
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
                tv = {
                    publicKey = "HrTCQLCg8TBAm/9+VfiOijQ17jRO18DrSyj+a/cpgDw=";
                    allowedIPs = [ "10.250.250.5/32" ];
                };
            };
            socks5Proxy = {
                enable = true;
                host = "127.0.0.1";
                port = 10808;
                redsocksPort = 12345;
            };
        };
    };
}
