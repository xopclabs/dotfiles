{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.traefik;
    
    # Helper function to create a Traefik route with sensible defaults
    # Usage: mkRoute { name = "service-name"; subdomain = "subdomain.vm.local"; backendUrl = "http://ip:port"; }
    mkRoute = { 
        name,
        subdomain,
        backendUrl,
        middlewares ? [ "default-headers" "https-redirect" "home-ipwhitelist" ],
        passHostHeader ? true,
        certResolver ? "cloudflare",
        entryPoints ? [ "websecure" ]
    }: {
        routers.${name} = {
            rule = "Host(`${subdomain}.$DOMAIN`)";
            inherit entryPoints middlewares;
            service = name;
            tls = { inherit certResolver; };
        };
        
        services.${name}.loadBalancer = {
            inherit passHostHeader;
            servers = [ { url = backendUrl; } ];
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
        
        routes = mkOption {
            type = types.listOf (types.submodule {
                options = {
                    name = mkOption {
                        type = types.str;
                        description = "Service name";
                    };
                    subdomain = mkOption {
                        type = types.str;
                        description = "Subdomain (e.g., 'pihole.vm.local')";
                    };
                    backendUrl = mkOption {
                        type = types.str;
                        description = "Backend URL (e.g., 'http://192.168.1.10:8080')";
                    };
                    middlewares = mkOption {
                        type = types.listOf types.str;
                        default = [ "default-headers" "https-redirect" "home-ipwhitelist" ];
                        description = "List of middlewares to apply";
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
                };
            });
            default = [];
            description = "List of routes to configure in Traefik";
        };
    };
    
    config = mkIf cfg.enable {
        sops.secrets.traefik = {
            sopsFile = ../secrets/hosts/${config.metadata.hostName}.yaml;
        };

        services.traefik = {
            enable = true;
            environmentFiles = [ config.sops.secrets.traefik.path ];

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
                        address = ":443";
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
                    middlewares = {
                        default-headers.headers = {
                            sslRedirect = true;
                            stsSeconds = 31536000;
                            stsIncludeSubdomains = true;
                            stsPreload = true;
                            forceSTSHeader = true;
                            frameDeny = true;
                            sslTemporaryRedirect = true;
                            browserXssFilter = true;
                            contentTypeNosniff = true;
                            referrerPolicy = "same-origin";
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
                        rule = "Host(`traefik.vm.local.$DOMAIN`)";
                        entryPoints = [ "websecure" ];
                        service = "api@internal";
                        middlewares = [
                            "default-headers"
                            "https-redirect"
                            "home-ipwhitelist"
                        ];
                        tls = {
                            certResolver = "cloudflare";
                            domains = [
                                {
                                    main = "*.vm.local.$DOMAIN";
                                    sans = [ "vm.local.$DOMAIN" ];
                                }
                            ];
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

        networking.firewall.allowedTCPPorts = [ 80 443 ];
    };
}