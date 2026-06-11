{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.pihole_unbound;

    localZonesFile = "/var/lib/pihole/local-zones.conf";

    sortedLocalZones =
        sort (a: b: (stringLength a) > (stringLength b)) (attrNames cfg.localZones);

    sync-to-orangepi = pkgs.writeShellScriptBin "sync-to-orangepi" ''${builtins.readFile ./sync-to-orangepi}'';
in
{
    options.homelab.pihole_unbound = {
        enable = mkEnableOption "Pi-hole and Unbound DNS services";
        
        unbound = {
            forwardUpstream = mkOption {
                type = types.bool;
                default = true;
                description = ''
                    Forward DNS queries to upstream servers over DNS-over-TLS.
                    When true: queries are encrypted and sent to Quad9 (better privacy from ISP).
                    When false: Unbound performs recursive resolution directly to root servers (no third-party trust).
                '';
            };
            
            upstreamServers = mkOption {
                type = types.listOf types.str;
                default = [
                    "9.9.9.9@853#dns.quad9.net"
                    "149.112.112.112@853#dns.quad9.net"
                ];
                description = "Upstream DNS-over-TLS servers (only used when forwardUpstream is true)";
            };
        };
        
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

            firewall = {
                dns = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Open firewall for DNS";
                };
                dhcp = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Open firewall for DHCP";
                };
                webserver = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Open firewall for Webserver";
                };
            };
        };

        localZones = mkOption {
            type = types.attrsOf types.str;
            default = {
                "vm.local" = "homelab";
                "local" = "homelab";
                "pi.local" = "pi";
                "vps.local" = "vps";
                "" = "vps";
            };
            example = {
                "vm.local" = "homelab";
                "pi.local" = "pi";
                "vps.local" = "vps";
                "local" = "homelab";
            };
            description = ''
                Private zones under $DOMAIN served only by Pi-hole (no public DNS).
                Values are short hostnames from the sops `hosts` file; IPs are read at
                runtime. List longer zones (e.g. `vps.local`) before the shorter `local`
                zone — dnsmasq uses longest suffix match, and a lone `local` rule would
                otherwise catch `traefik.vps.local.$DOMAIN`.
            '';
        };
    };

    config = mkIf cfg.enable {
        # Install sync script
        environment.systemPackages = [ sync-to-orangepi ];
        
        # Sops secret for domain name
        sops.secrets.domain = {
            sopsFile = ../../../secrets/shared/selfhost.yaml;
            owner = "unbound";
            mode = "0400";
            restartUnits = [ "unbound.service" "pihole-ftl.service" ];
        };

        # Sops secret for custom hosts
        sops.secrets.hosts = {
            sopsFile = ../../../secrets/shared/selfhost.yaml;
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
                    
                    # DNSSEC validation
                    auto-trust-anchor-file = "/var/lib/unbound/root.key";
                    
                    # TLS certificate bundle for upstream DoT
                    tls-cert-bundle = "/etc/ssl/certs/ca-certificates.crt";
                    
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
                
                forward-zone =
                    # TMDB domains always forwarded to Quad9 (bypass country-level DNS censorship)
                    [
                        {
                            name = "themoviedb.org";
                            forward-tls-upstream = true;
                            forward-addr = [ "9.9.9.9@853#dns.quad9.net" "149.112.112.112@853#dns.quad9.net" ];
                        }
                        {
                            name = "tmdb.org";
                            forward-tls-upstream = true;
                            forward-addr = [ "9.9.9.9@853#dns.quad9.net" "149.112.112.112@853#dns.quad9.net" ];
                        }
                        {
                            name = "image.tmdb.org";
                            forward-tls-upstream = true;
                            forward-addr = [ "9.9.9.9@853#dns.quad9.net" "149.112.112.112@853#dns.quad9.net" ];
                        }
                    ]
                    # Optionally forward all other queries to upstream DoT servers
                    ++ optional cfg.unbound.forwardUpstream {
                        name = ".";
                        forward-tls-upstream = true;
                        forward-addr = cfg.unbound.upstreamServers;
                    };
            };
        };
        
        systemd.services.unbound = {
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            preStart = mkAfter (
                if cfg.localZones != { } then
                    ''
                        ${pkgs.coreutils}/bin/cat > /var/lib/unbound/local-domain.conf <<EOF
                            server:
                        EOF
                        ${pkgs.coreutils}/bin/chown unbound:unbound /var/lib/unbound/local-domain.conf
                        ${pkgs.coreutils}/bin/chmod 644 /var/lib/unbound/local-domain.conf
                    ''
                else
                    ''
                        DOMAIN=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.domain.path})
                        ${if config.metadata.selfhost.mainIpv4 != null then ''
                        LOCAL_IP="${config.metadata.selfhost.mainIpv4}"
                        '' else ''
                        LOCAL_IP=$(${pkgs.iproute2}/bin/ip route get 1 | ${pkgs.gawk}/bin/awk '{print $7; exit}')
                        ''}
                        ${pkgs.coreutils}/bin/cat > /var/lib/unbound/local-domain.conf <<EOF
                            server:
                                local-zone: "local.$DOMAIN." redirect
                                local-data: "local.$DOMAIN. 3600 IN A $LOCAL_IP"
                        EOF
                        ${pkgs.coreutils}/bin/chown unbound:unbound /var/lib/unbound/local-domain.conf
                        ${pkgs.coreutils}/bin/chmod 644 /var/lib/unbound/local-domain.conf
                    ''
            );
        };

        # Pi-hole FTL DNS service
        services.pihole-ftl = {
            enable = true;
            openFirewallDNS = cfg.pihole.firewall.dns;
            openFirewallDHCP = cfg.pihole.firewall.dhcp;
            openFirewallWebserver = cfg.pihole.firewall.webserver;
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
                } // optionalAttrs (cfg.localZones != { }) {
                    dnsmasq_lines = [
                        "conf-file=${localZonesFile}"
                    ];
                };
            };
            privacyLevel = 0;
        };

        # "+" runs as root despite User=pihole; needed to read the domain sops secret
        # (owner unbound) and write /var/lib/pihole/local-zones.conf.
        systemd.services.pihole-ftl = mkIf (cfg.localZones != { }) {
            serviceConfig.ExecStartPre = mkBefore [
                "+${pkgs.writeShellScript "pihole-ftl-local-zones" ''
                    set -euo pipefail
                    DOMAIN=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.domain.path})
                    HOSTS=${config.sops.secrets.hosts.path}
                    lookup_host() {
                        ${pkgs.gawk}/bin/awk -v name="$1" '$2 == name { print $1; exit }' "$HOSTS"
                    }
                    ${pkgs.coreutils}/bin/mkdir -p /var/lib/pihole
                    {
                        ${concatMapStringsSep "\n" (
                            zone:
                            let
                                host = cfg.localZones.${zone};
                            in
                            ''
                                ip=$(lookup_host ${host})
                                if [ -n "$ip" ]; then
                                    echo "address=/${zone}.''${DOMAIN}/$ip"
                                fi
                            ''
                        ) sortedLocalZones}
                    } > ${localZonesFile}
                ''}"
            ];
        };
        
        services.pihole-web = {
            enable = true;
            ports = [ cfg.pihole.webPort ];
        };

        # Keep pihole-ftl-setup from stalling boot for 20+ minutes.
        # The upstream unit runs gravity and calls into pihole's config API on
        # every start, which can hang on slow blocklist downloads (e.g. oisd)
        # and currently also fails with a "type" param regression in the API.
        # Cap its runtime and ensure failures don't gate other units — gravity
        # will retry on its regular timer.
        systemd.services.pihole-ftl-setup = {
            serviceConfig = {
                TimeoutStartSec = lib.mkForce "2min";
                Restart = lib.mkForce "no";
            };
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

