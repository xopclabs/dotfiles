{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.pihole_unbound;
in
{
    options.homelab.pihole_unbound = {
        enable = mkEnableOption "Pi-hole and Unbound DNS services";
        
        pihole = {
            subdomain = mkOption {
                type = types.str;
                description = "Subdomain for Pi-hole";
            };

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
            sopsFile = ../../secrets/shared/selfhost.yaml;
            owner = "unbound";
            mode = "0400";
            restartUnits = [ "unbound.service" "pihole-ftl.service" ];
        };

        # Sops secret for custom hosts
        sops.secrets.hosts = {
            sopsFile = ../../secrets/shared/selfhost.yaml;
            path = "/etc/dnsmasq.d/custom-hosts";
            owner = "root";
            group = "root";
            mode = "0644";
            restartUnits = [ "unbound.service" "pihole-ftl.service" ];
        };
        # Configure dnsmasq to use custom hosts file
        environment.etc."dnsmasq.d/custom-hosts.conf".text = ''
            addn-hosts=/etc/dnsmasq.d/custom-hosts
        '';
        

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
                
                # Forward TMDB domains to Quad9 to bypass country-level DNS censorship
                forward-zone = [
                    {
                        name = "themoviedb.org";
                        forward-addr = [ "9.9.9.9" "149.112.112.112" ];
                    }
                    {
                        name = "tmdb.org";
                        forward-addr = [ "9.9.9.9" "149.112.112.112" ];
                    }
                    {
                        name = "image.tmdb.org";
                        forward-addr = [ "9.9.9.9" "149.112.112.112" ];
                    }
                ];
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
                misc = {
                    # Enable for extra hosts
                    etc_dnsmasq_d = true;
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
                subdomain = cfg.pihole.subdomain;
                backendUrl = "http://127.0.0.1:${cfg.pihole.webPort}";
            }
        ];

        # Register with Glance dashboard
        homelab.glance.services = mkIf config.homelab.glance.enable [
            {
                title = "Pihole";
                subdomain = cfg.pihole.subdomain;
                icon = "si:pihole";
                group = "Services";
            }
        ];
    };
}

