{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.services.homelab.wireguard;
    
    # Function to generate peer configuration
    mkPeer = name: peerCfg: {
        publicKey = peerCfg.publicKey;
        presharedKeyFile = config.sops.secrets."wg/peers/${name}/presharedkey".path;
        allowedIPs = peerCfg.allowedIPs;
        persistentKeepalive = 25;
    };
    
    generate-wg-client = pkgs.writeShellScriptBin "generate-wg-client" ''${builtins.readFile ./generate-wg-client}'';
in
{
    options.services.homelab.wireguard = {
        enable = mkEnableOption "WireGuard VPN server";
            
        listenPort = mkOption {
            type = types.port;
            default = 51820;
            description = "Port to listen on";
        };
        
        serverIP = mkOption {
            type = types.str;
            default = "10.250.250.1/24";
            description = "Server IP address and subnet";
        };
        
        subnet = mkOption {
            type = types.str;
            default = "10.250.250.0/24";
            description = "VPN subnet";
        };
        
        externalInterface = mkOption {
            type = types.str;
            default = "ens18";
            description = "External network interface for NAT";
        };
        
        peers = mkOption {
            type = types.attrsOf (types.submodule {
                options = {
                    publicKey = mkOption {
                        type = types.str;
                        description = "Public key of the peer";
                    };
                    allowedIPs = mkOption {
                        type = types.listOf types.str;
                        description = "Allowed IP addresses for this peer";
                    };
                };
            });
            default = {};
            description = "WireGuard peers configuration";
        };
    };
    
    config = mkIf cfg.enable {
        environment.systemPackages = with pkgs; [
            wireguard-tools
            sops
            qrrs
            generate-wg-client
        ];

        sops.secrets = mkMerge [
            {
                "wg/privatekey" = {
                    sopsFile = ../../secrets/hosts/${config.networking.hostName}.yaml;
                    owner = "root";
                    group = "root";
                    mode = "0400";
                };
            }
            (mapAttrs' (name: _: {
                name = "wg/peers/${name}/presharedkey"; 
                value = { 
                    sopsFile = ../../secrets/hosts/${config.networking.hostName}.yaml;
                    owner = "root"; 
                    group = "root"; 
                    mode = "0400"; 
                }; 
                } ) cfg.peers)
        ];

        networking.wireguard.interfaces."wg0" = {
            ips = [ cfg.serverIP ];
            listenPort = cfg.listenPort;
            privateKeyFile = config.sops.secrets."wg/privatekey".path;

            postSetup = ''
                ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s ${cfg.subnet} -o eth0 -j MASQUERADE
            '';
            postShutdown = ''
                ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s ${cfg.subnet} -o eth0 -j MASQUERADE
            '';

            peers = mapAttrsToList mkPeer cfg.peers;
        };

        # Enable IPv4 forwarding system‑wide.
        boot.kernel.sysctl."net.ipv4.ip_forward" = true;

        # Masquerade wireguard traffic as lan traffic
        networking.nat = {
            enable = true;
            externalInterface = cfg.externalInterface;
            internalInterfaces = [ "wg0" ];
        };
        
        # Allow wireguard traffic
        networking.firewall.allowedUDPPorts = [ cfg.listenPort ];
    };
}

