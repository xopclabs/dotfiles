{ config, pkgs, lib, ... }:

let
    # Define peers with minimal configuration
    peers = {
        vps = {
            publicKey = "HK4EezS2UTm64clhYLBa4QHAN/0ad/eyfv14N2ffnyA=";
            allowedIPs = [ "10.250.250.2/32" ];
        };
    };

    # Function to generate peer configuration
    mkPeer = name: cfg: {
        publicKey = cfg.publicKey;
        presharedKeyFile = config.sops.secrets."wg/peers/${name}/presharedkey".path;
        allowedIPs = cfg.allowedIPs;
        persistentKeepalive = 25;
    };

    # Generate secrets for each peer
    mkPeerSecrets = name: _: {
        "wg/peers/${name}/presharedkey" = {
            owner = "root";
            group = "root";
            mode = "0400";
        };
    };
in
{
    environment.systemPackages = with pkgs; [
        wireguard-tools
        sops
        yq
    ];

    sops.secrets = lib.mkMerge [
        {
            "wg/privatekey" = {
                owner = "root";
                group = "root";
                mode = "0400";
            };
        }
        (lib.mapAttrs' (name: _: {
            name = "wg/peers/${name}/presharedkey"; 
            value = { 
                owner = "root"; 
                group = "root"; 
                mode = "0400"; 
            }; 
        } ) peers)
    ];

    networking.wireguard.interfaces."wg0" = {
        ips = [ "10.250.250.1/24" ];
        listenPort = 51820;
        privateKeyFile = config.sops.secrets."wg/privatekey".path;

        postSetup = ''
            ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.250.250.0/24 -o eth0 -j MASQUERADE
        '';
        postShutdown = ''
            ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.250.250.0/24 -o eth0 -j MASQUERADE
        '';

        peers = lib.mapAttrsToList mkPeer peers;
    };

    # Enable IPv4 forwarding system‑wide.
    boot.kernel.sysctl."net.ipv4.ip_forward" = true;

    # Masquerade wireguard traffic as lan traffic
    networking.nat = {
        enable = true;
        externalInterface = "ens18";
        internalInterfaces = [ "wg0" ];
    };
    
    # Allow wireguard traffic
    networking.firewall.allowedUDPPorts = [ 51820 ];
}
