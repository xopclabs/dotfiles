{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.pihole_unbound;
in
{
    options.homelab.pihole_unbound = {
        enable = mkEnableOption "Pi-hole and Unbound DNS services";
        
        pihole = {
            webPort = mkOption {
                type = types.str;
                default = "8080";
                description = "Port for Pi-hole web interface";
            };
            
            lists = mkOption {
                type = types.listOf (types.attrsOf types.str);
                default = [
                    {
                        url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts";
                        description = "Steven Black's unified hosts (ads + malware)";
                    }
                    {
                        url = "https://blocklistproject.github.io/Lists/ads.txt";
                        description = "BlocklistProject - Ads";
                    }
                    {
                        url = "https://blocklistproject.github.io/Lists/tracking.txt";
                        description = "BlocklistProject - Tracking";
                    }
                    {
                        url = "https://blocklistproject.github.io/Lists/malware.txt";
                        description = "BlocklistProject - Malware";
                    }
                    {
                        url = "https://blocklistproject.github.io/Lists/phishing.txt";
                        description = "BlocklistProject - Phishing";
                    }
                    {
                        url = "https://big.oisd.nl/domainswild";
                        description = "OISD Big List";
                    }
                ];
                description = "List of blocklists for Pi-hole";
            };
        };
    };
    
    config = mkIf cfg.enable {
        # Sops secret for domain name
        sops.secrets.domain = {
            sopsFile = ../secrets/hosts/${config.metadata.hostName}.yaml;
            owner = "unbound";
            mode = "0400";
        };

        services.unbound = {
            enable = true;
            
            settings = {
                server = {
                    # Listen only on localhost for Pi-hole to use
                    interface = [ "127.0.0.1" "::1" ];
                    port = 5335;
                    
                    # Access control
                    access-control = [
                        "127.0.0.0/8 allow"
                        "::1/128 allow"
                    ];
                    
                    # Performance tuning
                    num-threads = 4;
                    msg-cache-slabs = 8;
                    rrset-cache-slabs = 8;
                    infra-cache-slabs = 8;
                    key-cache-slabs = 8;
                    
                    # Memory cache sizes
                    rrset-cache-size = "256m";
                    msg-cache-size = "128m";
                    
                    # Prefetching
                    prefetch = true;
                    prefetch-key = true;
                    
                    # Privacy and security
                    hide-identity = true;
                    hide-version = true;
                    qname-minimisation = true;
                    
                    # DNSSEC
                    auto-trust-anchor-file = "/var/lib/unbound/root.key";
                    
                    # Logging
                    verbosity = 1;
                    log-queries = false;
                    
                    # Performance settings
                    so-rcvbuf = "4m";
                    so-sndbuf = "4m";
                    
                    # Include local domain configuration generated from secret
                    include = "/var/lib/unbound/local-domain.conf";
                };
                
                remote-control = {
                    control-enable = true;
                    control-interface = "127.0.0.1";
                };
            };
        };
        
        # Route all local.PERSONAL_DOMAIN requests to this machine
        systemd.services.unbound.preStart = mkAfter ''
            DOMAIN=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.domain.path})
            ${pkgs.coreutils}/bin/cat > /var/lib/unbound/local-domain.conf <<EOF
                server:
                    local-zone: "local.$DOMAIN." redirect
                    local-data: "local.$DOMAIN. 3600 IN A ${config.metadata.network.ipv4}"
            EOF
            ${pkgs.coreutils}/bin/chown unbound:unbound /var/lib/unbound/local-domain.conf
            ${pkgs.coreutils}/bin/chmod 644 /var/lib/unbound/local-domain.conf
        '';
        
        # Pi-hole FTL DNS service
        services.pihole-ftl = {
            enable = true;
            openFirewallDNS = true;
            openFirewallDHCP = true;
            openFirewallWebserver = true;
            lists = cfg.pihole.lists;
            
            settings = {
                dns = {
                    # Use Unbound as upstream DNS
                    upstreams = [ "127.0.0.1#5335" ];
                    dnssec = true;
                };
            };
            privacyLevel = 0;
        };
        
        services.pihole-web = {
            enable = true;
            ports = [ cfg.pihole.webPort ];
        };
        
        # Disable systemd-resolved to avoid port conflicts
        services.resolved.enable = mkForce false;
        
        # Register with Traefik if enabled
        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "pihole";
                subdomain = "pihole.vm.local";
                backendUrl = "http://127.0.0.1:${cfg.pihole.webPort}";
            }
        ];
    };
}

