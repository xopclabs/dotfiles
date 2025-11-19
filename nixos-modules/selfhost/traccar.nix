{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.traccar;
in
{
    options.homelab.traccar = {
        enable = mkEnableOption "Traccar GPS tracking system";

        subdomain = mkOption {
            type = types.str;
            description = "Subdomain for Traccar";
        };
    };
    
    config = mkIf cfg.enable {
        # Enable PostgreSQL with Traccar database
        homelab.postgres = {
            enable = true;
            databases = [ "traccar" ];
            ensureUsers = [
                {
                    name = "traccar";
                    ensureDBOwnership = true;
                }
            ];
        };
        
        services.traccar = {
            enable = true;
            
            settings = {
                web = {
                    port = "8082";
                    override = "/var/lib/traccar/override";
                };
                database = {
                    driver = "org.postgresql.Driver";
                    url = "jdbc:postgresql://localhost:${toString config.homelab.postgres.port}/traccar";
                    user = "traccar";
                };
            };
        };
        
        # Ensure Traccar starts after PostgreSQL
        systemd.services.traccar = {
            after = [ "postgresql.service" ];
            requires = [ "postgresql.service" ];
        };
        
        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "traccar";
                subdomain = cfg.subdomain;
                backendUrl = "http://127.0.0.1:8082";
            }
            {
                name = "traccar-api";
                subdomain = "api.${cfg.subdomain}";
                backendUrl = "http://127.0.0.1:5055";
                # Explicitly allow public access even on .local subdomain
                middlewares = [ "default-headers" "https-redirect" ];
            }
        ];
    };
}

