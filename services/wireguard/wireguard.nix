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
        ];

        sops.secrets = mkMerge [
            {
                "wg/privatekey" = {
                    sopsFile = ../../secrets/hosts/${config.metadata.hostName}.yaml;
                    owner = "root";
                    group = "root";
                    mode = "0400";
                };
            }
            (mapAttrs' (name: _: {
                name = "wg/peers/${name}/presharedkey"; 
                value = { 
                    sopsFile = ../../secrets/hosts/${config.metadata.hostName}.yaml;
                    owner = "root"; 
                    group = "root"; 
                    mode = "0400"; 
                }; 
                } ) cfg.peers)
        ];

        # Redsocks service for transparent SOCKS5 proxying
        services.redsocks = mkIf (cfg.socks5Proxy != null && cfg.socks5Proxy.enable) {
            enable = true;
            redsocks = [{
                type = "socks5";
                proxy = "${cfg.socks5Proxy.host}:${toString cfg.socks5Proxy.port}";
                port = cfg.socks5Proxy.redsocksPort;
            }];
        };

        networking.wireguard.interfaces."wg0" = {
            ips = [ cfg.serverIP ];
            listenPort = cfg.listenPort;
            privateKeyFile = config.sops.secrets."wg/privatekey".path;

            postSetup = ''
                ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s ${cfg.subnet} -o ${cfg.externalInterface} -j MASQUERADE
                
                ${optionalString (cfg.socks5Proxy != null && cfg.socks5Proxy.enable) ''
                    # Enable route_localnet for wg0 to allow transparent proxy to localhost
                    echo 1 > /proc/sys/net/ipv4/conf/wg0/route_localnet
                    
                    # Create a custom chain for proxy redirection
                    ${pkgs.iptables}/bin/iptables -t nat -N WG_PROXY 2>/dev/null || true
                    ${pkgs.iptables}/bin/iptables -t nat -F WG_PROXY
                    
                    # Don't proxy local networks
                    ${concatMapStringsSep "\n" (net: 
                        "    ${pkgs.iptables}/bin/iptables -t nat -A WG_PROXY -d ${net} -j RETURN"
                    ) cfg.localNetworks}
                    
                    # Don't proxy the SOCKS5 proxy server itself
                    ${pkgs.iptables}/bin/iptables -t nat -A WG_PROXY -d ${cfg.socks5Proxy.host} -j RETURN
                    
                    # Redirect all other TCP traffic to redsocks
                    ${pkgs.iptables}/bin/iptables -t nat -A WG_PROXY -p tcp -j REDIRECT --to-ports ${toString cfg.socks5Proxy.redsocksPort}
                    
                    # Apply the chain to WireGuard traffic
                    ${pkgs.iptables}/bin/iptables -t nat -A PREROUTING -i wg0 -p tcp -j WG_PROXY
                ''}
            '';
            
            postShutdown = ''
                ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s ${cfg.subnet} -o ${cfg.externalInterface} -j MASQUERADE
                
                ${optionalString (cfg.socks5Proxy != null && cfg.socks5Proxy.enable) ''
                    # Disable route_localnet for wg0
                    echo 0 > /proc/sys/net/ipv4/conf/wg0/route_localnet 2>/dev/null || true
                    
                    # Remove the proxy chain
                    ${pkgs.iptables}/bin/iptables -t nat -D PREROUTING -i wg0 -p tcp -j WG_PROXY 2>/dev/null || true
                    ${pkgs.iptables}/bin/iptables -t nat -F WG_PROXY 2>/dev/null || true
                    ${pkgs.iptables}/bin/iptables -t nat -X WG_PROXY 2>/dev/null || true
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

