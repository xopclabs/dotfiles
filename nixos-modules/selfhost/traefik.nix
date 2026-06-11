{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.traefik;
    
    # Helper function to determine if a subdomain requires IP whitelisting
    # Local subdomains (*.local) should be whitelisted, public ones should not
    requiresWhitelist = subdomain: 
        builtins.match ".*\\.local$" subdomain != null;
    
    # Helper function to create a Traefik route with sensible defaults
    # Usage: mkRoute { name = "service-name"; subdomain = "subdomain.vm.local"; backendUrl = "http://ip:port"; }
    mkRoute = { 
        name,
        subdomain,
        backendUrl,
        middlewares ? null,
        passHostHeader ? true,
        certResolver ? "cloudflare",
        entryPoints ? [ "websecure" ],
        insecureSkipVerify ? false,
        clientCert ? null,
        serversTransport ? null,
        publicAlias ? null,
        publicCertDomains ? [ { main = "$DOMAIN"; sans = [ "*.$DOMAIN" ]; } ]
    }: 
    let
        # Determine default middlewares based on subdomain pattern
        defaultMiddlewares = 
            if requiresWhitelist subdomain
            then [ "default-headers" "https-redirect" "home-ipwhitelist" ]
            else [ "default-headers" "https-redirect" ];
        
        actualMiddlewares = if middlewares != null then middlewares else defaultMiddlewares;
        
        # Determine which serversTransport to use (explicit > clientCert > insecureSkipVerify)
        transport = 
            if serversTransport != null then serversTransport
            else if clientCert != null then clientCert
            else if insecureSkipVerify then "insecureTransport"
            else null;
    in {
        routers = {
            ${name} = {
                rule = "Host(`${subdomain}.$DOMAIN`)";
                inherit entryPoints;
                middlewares = actualMiddlewares;
                service = name;
                tls = { inherit certResolver; };
            };
        } // optionalAttrs (publicAlias != null) {
            # Sibling router that exposes the same backend on a public hostname.
            # Routed via a separate path (typically a SNI-passthrough relay on a
            # public VPS), so it gets only public middlewares (no IP whitelist)
            # and pre-orders its own cert via the same DNS-01 resolver.
            "${name}-public" = {
                rule = "Host(`${publicAlias}.$DOMAIN`)";
                inherit entryPoints;
                middlewares = [ "default-headers" "https-redirect" ];
                service = name;
                tls = {
                    inherit certResolver;
                    domains = publicCertDomains;
                };
            };
        };

        services.${name}.loadBalancer = {
            inherit passHostHeader;
            servers = [ { url = backendUrl; } ];
        } // optionalAttrs (transport != null) {
            serversTransport = transport;
        };
    };
    
    # Generate the dynamic config file
    format = pkgs.formats.toml { };
    dynamicConfigFile = format.generate "dynamic-config.toml" 
        config.services.traefik.dynamicConfigOptions;
in
{
    options.homelab.traefik = {
        enable = mkEnableOption "Traefik reverse proxy";

        dashboardSubdomain = mkOption {
            type = types.str;
            default = "traefik.vm.local";
            description = "Subdomain for Traefik dashboard (e.g., 'traefik.vm.local' or 'traefik.vps.local')";
        };

        websecureAddress = mkOption {
            type = types.str;
            default = ":443";
            example = "127.0.0.1:8443";
            description = ''
                Address for the HTTPS (websecure) entrypoint. Defaults to the
                public ":443". Set to a loopback address (e.g. "127.0.0.1:8443")
                when another service (such as the Reality proxy) owns the public
                :443 and forwards non-proxy TLS here. When loopback, Traefik no
                longer opens :443 in the firewall.
            '';
        };

        proxyProtocolTrustedIPs = mkOption {
            type = types.listOf types.str;
            default = [];
            example = [ "127.0.0.1/32" ];
            description = ''
                Trusted source IPs for PROXY protocol on the websecure entrypoint.
                When non-empty, Traefik reads the real client IP from the PROXY
                protocol header (used when a front proxy like Xray/Reality with
                xver forwards connections to a loopback entrypoint).
            '';
        };

        certificateDomains = mkOption {
            type = types.listOf (types.submodule {
                options = {
                    main = mkOption {
                        type = types.str;
                        description = "Main domain pattern (e.g., '*.vm.local.$DOMAIN' or '*.$DOMAIN')";
                    };
                    sans = mkOption {
                        type = types.listOf types.str;
                        default = [];
                        description = "Subject Alternative Names";
                    };
                };
            });
            default = [
                {
                    main = "*.vm.local.$DOMAIN";
                    sans = [ "vm.local.$DOMAIN" ];
                }
            ];
            description = "List of certificate domain patterns to request";
        };

        routes = mkOption {
            type = types.listOf (types.submodule {
                options = {
                    name = mkOption {
                        type = types.str;
                        description = "Service name";
                    };
                    subdomain = mkOption {
                        type = types.str;
                        description = "Subdomain (e.g., 'pihole.vm.local', 'api', etc.)";
                    };
                    backendUrl = mkOption {
                        type = types.str;
                        description = "Backend URL (e.g., 'http://192.168.1.10:8080')";
                    };
                    middlewares = mkOption {
                        type = types.nullOr (types.listOf types.str);
                        default = null;
                        description = "List of middlewares to apply (null = auto-detect based on subdomain)";
                    };
                    passHostHeader = mkOption {
                        type = types.bool;
                        default = true;
                        description = "Pass host header to backend";
                    };
                    certResolver = mkOption {
                        type = types.str;
                        default = "cloudflare";
                        description = "Certificate resolver to use";
                    };
                    entryPoints = mkOption {
                        type = types.listOf types.str;
                        default = [ "websecure" ];
                        description = "Entry points for the route";
                    };
                    insecureSkipVerify = mkOption {
                        type = types.bool;
                        default = false;
                        description = "Skip TLS verification for backends with self-signed certificates";
                    };
                    clientCert = mkOption {
                        type = types.nullOr types.str;
                        default = null;
                        description = "Name of serversTransport with client certificate (for mTLS backends like Incus)";
                    };
                    serversTransport = mkOption {
                        type = types.nullOr types.str;
                        default = null;
                        description = "Name of serversTransport to use (e.g., 'defaultTransport' for long upload timeouts)";
                    };
                    publicAlias = mkOption {
                        type = types.nullOr types.str;
                        default = null;
                        example = "jellyfin";
                        description = ''
                            Optional public-facing subdomain alias for this service.
                            When set, generates a sibling router named `<name>-public`
                            that matches `Host(<publicAlias>.$DOMAIN)`, points at the
                            same `service = <name>` (no duplicated backend), uses only
                            public middlewares (no IP whitelist), and orders its own
                            cert via `publicCertDomains`.

                            Intended for services exposed externally via a SNI-pass-
                            through relay (e.g. a public VPS forwarding raw TLS to
                            this host over WireGuard). The internal route declared by
                            `subdomain` is left untouched.
                        '';
                    };
                    publicCertDomains = mkOption {
                        type = types.listOf (types.submodule {
                            options = {
                                main = mkOption {
                                    type = types.str;
                                    description = "Main domain pattern for the public alias cert";
                                };
                                sans = mkOption {
                                    type = types.listOf types.str;
                                    default = [];
                                    description = "Subject Alternative Names";
                                };
                            };
                        });
                        default = [ { main = "$DOMAIN"; sans = [ "*.$DOMAIN" ]; } ];
                        description = ''
                            Certificate domains to request for the public alias router.
                            Defaults to a wildcard for `$DOMAIN`. Only used when
                            `publicAlias` is set.
                        '';
                    };
                };
            });
            default = [];
            description = "List of routes to configure in Traefik";
        };

        # Client certificates for mTLS to backends (e.g., Incus)
        # Secrets should be stored in sops as traefik.certs.<name>/cert and .../key
        clientCerts = mkOption {
            type = types.attrsOf (types.submodule {
                options = {
                    insecureSkipVerify = mkOption {
                        type = types.bool;
                        default = true;
                        description = "Skip server certificate verification";
                    };
                };
            });
            default = {};
            description = ''
                Client certificates for mTLS connections to backends.
                For each entry, you must add PEM-encoded secrets to sops:
                - traefik.certs.<name>/cert - the client certificate
                - traefik.certs.<name>/key - the private key
            '';
        };
    };
    
    config = mkIf cfg.enable {
        sops.secrets = {
            "traefik/env" = {
                sopsFile = ../../secrets/shared/selfhost.yaml;
            };
        } // mapAttrs' (name: certCfg: {
            name = "traefik/certs/${name}/cert";
            value = {
                sopsFile = ../../secrets/shared/selfhost.yaml;
                owner = "traefik";
                group = "traefik";
            };
        }) cfg.clientCerts // mapAttrs' (name: certCfg: {
            name = "traefik/certs/${name}/key";
            value = {
                sopsFile = ../../secrets/shared/selfhost.yaml;
                owner = "traefik";
                group = "traefik";
            };
        }) cfg.clientCerts;

        services.traefik = {
            enable = true;
            environmentFiles = [ config.sops.secrets."traefik/env".path ];

            staticConfigOptions = {
                global = {
                    checkNewVersion = false;
                    sendAnonymousUsage = false;
                };

                api = {
                    dashboard = true;
                    debug = false;
                    insecure = false; 
                };

                entryPoints = {
                    web = {
                        address = ":80";
                        http = {
                            redirections.entryPoint = {
                                to = "websecure";
                                scheme = "https";
                            };
                        };
                    };

                    websecure = {
                        address = cfg.websecureAddress;
                        transport.respondingTimeouts = {
                            readTimeout = "600s";   # 10 minutes for large uploads
                            writeTimeout = "600s";
                            idleTimeout = "180s";
                        };
                    } // optionalAttrs (cfg.proxyProtocolTrustedIPs != []) {
                        proxyProtocol.trustedIPs = cfg.proxyProtocolTrustedIPs;
                    };
                };

                certificatesResolvers.cloudflare.acme = {
                    email = builtins.getEnv "CF_API_EMAIL";
                    storage = "/var/lib/traefik/acme.json";
                    dnsChallenge = {
                        provider = "cloudflare";
                    };
                };

                log = {
                    level = "INFO";
                    format = "json";
                    filePath = "/var/lib/traefik/traefik.log";
                };

                accessLog = {
                    filePath = "/var/lib/traefik/access.log";
                    bufferingSize = 100;
                    fields = {
                        defaultMode = "keep";
                        headers = {
                            defaultMode = "keep";
                            names = {
                                "X-Forwarded-For" = "keep";
                                "CF-Connecting-IP" = "keep";
                                "X-Real-IP" = "keep";
                            };
                        };
                    };
                };
            };

            dynamicConfigOptions.http = mkMerge ([
                {
                    # Transport for backends with self-signed certificates
                    serversTransports = {
                        insecureTransport.insecureSkipVerify = true;
                        # Long timeout for large file uploads (Immich, Nextcloud, etc.)
                        defaultTransport.forwardingTimeouts.responseHeaderTimeout = "600s";
                    } // (mapAttrs (name: certCfg: {
                        # Client certificate transport for mTLS backends
                        insecureSkipVerify = certCfg.insecureSkipVerify;
                        certificates = [{
                            certFile = config.sops.secrets."traefik/certs/${name}/cert".path;
                            keyFile = config.sops.secrets."traefik/certs/${name}/key".path;
                        }];
                    }) cfg.clientCerts);

                    middlewares = {
                        default-headers.headers = {
                            sslRedirect = true;
                            stsSeconds = 31536000;
                            stsIncludeSubdomains = true;
                            stsPreload = true;
                            forceSTSHeader = true;
                            sslTemporaryRedirect = true;
                            browserXssFilter = true;
                            contentTypeNosniff = true;
                            referrerPolicy = "same-origin";
                            # We'll trust the self-hosted services to behave (this is needed so that I won't need to create a separate header for Proxmox to use noVNC there)
                            frameDeny = false;
                        };

                        https-redirect.redirectScheme = {
                            scheme = "https";
                            permanent = true;
                        };

                        home-ipwhitelist.ipWhiteList.sourceRange = [
                            "192.168.0.0/16"
                            "10.0.0.0/8"
                            "172.16.0.0/12"
                            "127.0.0.1/32"
                        ];

                        primary.chain.middlewares = [
                            "home-ipwhitelist"
                            "https-redirect"
                            "default-headers"
                        ];
                    };

                    routers.traefik = {
                        rule = "Host(`${cfg.dashboardSubdomain}.$DOMAIN`)";
                        entryPoints = [ "websecure" ];
                        service = "api@internal";
                        # Force dashboard to always use home-ipwhitelist middleware
                        middlewares = [ "default-headers" "https-redirect" "home-ipwhitelist" ];
                        tls = {
                            certResolver = "cloudflare";
                            domains = cfg.certificateDomains;
                        };
                    };
                }
            ] ++ (map (route: mkRoute route) cfg.routes));
            dynamicConfigFile = dynamicConfigFile;
        };

        # Override the Traefik systemd service to also apply envsubst to dynamic config
        systemd.services.traefik.serviceConfig.ExecStartPre = mkAfter [
            (pkgs.writeShellScript "traefik-dynamic-config-envsubst" ''
                # Apply environment variable substitution to dynamic config
                umask 077
                ${pkgs.envsubst}/bin/envsubst -i "${dynamicConfigFile}" > "/run/traefik/dynamic-config.toml"
                
                # Update the static config to point to our substituted dynamic config
                ${pkgs.gnused}/bin/sed -i "s#${dynamicConfigFile}#/run/traefik/dynamic-config.toml#g" /run/traefik/config.toml
            '')
        ];

        # Open :443 publicly only when the websecure entrypoint is public.
        # When it binds a loopback address (e.g. behind a Reality front proxy),
        # the front proxy opens :443 instead.
        networking.firewall.allowedTCPPorts = [ 80 ]
            ++ optional (hasPrefix ":" cfg.websecureAddress || hasPrefix "0.0.0.0:" cfg.websecureAddress) 443;

        # Register with Glance dashboard
        homelab.glance.services = mkIf config.homelab.glance.enable [
            {
                title = "Traefik";
                subdomain = cfg.dashboardSubdomain;
                icon = "si:traefikproxy";
                group = "Other";
            }
        ];
    };
}