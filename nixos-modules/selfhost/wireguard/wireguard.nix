{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.wireguard;
    
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
    options.homelab.wireguard = {
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
        
        localNetworks = mkOption {
            type = types.listOf types.str;
            default = [ "192.168.0.0/16" "10.0.0.0/8" "172.16.0.0/12" ];
            description = "Local networks that should not be proxied";
        };
        
        socks5Proxy = mkOption {
            type = types.nullOr (types.submodule {
                options = {
                    enable = mkEnableOption "SOCKS5 transparent proxy for WireGuard traffic";
                    host = mkOption {
                        type = types.str;
                        description = "SOCKS5 proxy host";
                    };
                    port = mkOption {
                        type = types.port;
                        description = "SOCKS5 proxy port";
                    };
                    redsocksPort = mkOption {
                        type = types.port;
                        default = 12345;
                        description = "Local port for redsocks to listen on";
                    };
                };
            });
            default = null;
            description = "SOCKS5 proxy configuration for transparent proxying";
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
        ] ++ (if cfg.socks5Proxy != null && cfg.socks5Proxy.enable then [ pkgs.tun2socks ] else []);

        sops.secrets = mkMerge [
            {
                "wg/privatekey" = {
                    sopsFile = ../../../secrets/hosts/${config.metadata.hostName}.yaml;
                    owner = "root";
                    group = "root";
                    mode = "0400";
                };
            }
            (mapAttrs' (name: _: {
                name = "wg/peers/${name}/presharedkey"; 
                value = { 
                    sopsFile = ../../../secrets/hosts/${config.metadata.hostName}.yaml;
                    owner = "root"; 
                    group = "root"; 
                    mode = "0400"; 
                }; 
                } ) cfg.peers)
        ];

        # tun2socks service for routing traffic through SOCKS5 proxy
        systemd.services.tun2socks = mkIf (cfg.socks5Proxy != null && cfg.socks5Proxy.enable) {
            description = "tun2socks SOCKS5 tunnel";
            before = [ "wireguard-wg0.service" ];
            wantedBy = [ "multi-user.target" ];
            
            serviceConfig = {
                Type = "forking";
                Restart = "on-failure";
                RestartSec = "5s";
            };
            
            script = ''
                # Create TUN interface
                ${pkgs.iproute2}/bin/ip tuntap add mode tun dev tun0
                ${pkgs.iproute2}/bin/ip addr add 10.250.251.1/24 dev tun0
                ${pkgs.iproute2}/bin/ip link set dev tun0 up
                
                # Setup routing for WireGuard traffic through tun0
                ${pkgs.iproute2}/bin/ip rule add from ${cfg.subnet} table 100 priority 100 2>/dev/null || true
                ${pkgs.iproute2}/bin/ip route add default dev tun0 table 100
                
                # Add routes for local networks to bypass proxy
                ${concatMapStringsSep "\n" (net: 
                    "    ${pkgs.iproute2}/bin/ip route add ${net} dev wg0 table 100"
                ) cfg.localNetworks}
                
                # Start tun2socks in background
                ${pkgs.tun2socks}/bin/tun2socks -device tun0 -proxy socks5://${cfg.socks5Proxy.host}:${toString cfg.socks5Proxy.port} &
                echo $! > /run/tun2socks.pid
            '';
            
            postStop = ''
                # Stop tun2socks
                if [ -f /run/tun2socks.pid ]; then
                    kill $(cat /run/tun2socks.pid) 2>/dev/null || true
                    rm /run/tun2socks.pid
                fi
                
                # Remove routing rules
                ${pkgs.iproute2}/bin/ip rule del from ${cfg.subnet} table 100 2>/dev/null || true
                ${pkgs.iproute2}/bin/ip route flush table 100 2>/dev/null || true
                
                # Remove TUN interface
                ${pkgs.iproute2}/bin/ip link del tun0 2>/dev/null || true
            '';
        };

        networking.wireguard.interfaces."wg0" = {
            ips = [ cfg.serverIP ];
            listenPort = cfg.listenPort;
            privateKeyFile = config.sops.secrets."wg/privatekey".path;

            postSetup = ''
                # MASQUERADE for WireGuard traffic
                ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s ${cfg.subnet} -o ${cfg.externalInterface} -j MASQUERADE
                
                ${optionalString (cfg.socks5Proxy != null && cfg.socks5Proxy.enable) ''
                    # MASQUERADE for tun0 traffic going out to external interface
                    ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.250.251.0/24 -o ${cfg.externalInterface} -j MASQUERADE
                    
                    # Block QUIC (UDP 443) to force apps to use TCP/HTTPS which works better through SOCKS5
                    ${pkgs.iptables}/bin/iptables -I FORWARD -i wg0 -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable
                ''}
            '';
            
            postShutdown = ''
                ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s ${cfg.subnet} -o ${cfg.externalInterface} -j MASQUERADE 2>/dev/null || true
                
                ${optionalString (cfg.socks5Proxy != null && cfg.socks5Proxy.enable) ''
                    # Remove MASQUERADE for tun0
                    ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.250.251.0/24 -o ${cfg.externalInterface} -j MASQUERADE 2>/dev/null || true
                    
                    # Remove QUIC block rule
                    ${pkgs.iptables}/bin/iptables -D FORWARD -i wg0 -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable 2>/dev/null || true
                ''}
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

