{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.transmission;
in
{
    options.homelab.transmission = {
        enable = mkEnableOption "Transmission BitTorrent client with Flood UI";

        subdomain = mkOption {
            type = types.str;
            description = "Subdomain for Flood UI";
        };
    };
    
    config = mkIf cfg.enable {
        services.transmission = {
            enable = true;
            package = pkgs.transmission_4;
            webHome = pkgs.flood-for-transmission;
            
            settings = {
                download-dir = config.metadata.selfhost.storage.downloads.otherDir;

                incomplete-dir-enabled = true;
                incomplete-dir = config.metadata.selfhost.storage.downloads.incompleteDir;
                
                rpc-enabled = true;
                rpc-port = 9091;
                rpc-bind-address = "127.0.0.1";
            };
        };
        
        # Create necessary directories
        systemd.tmpfiles.rules = [
            "d ${config.metadata.selfhost.storage.downloads.otherDir} 0775 transmission transmission -"
            "d ${config.metadata.selfhost.storage.downloads.incompleteDir} 0775 transmission transmission -"
        ];
        
        # Flood UI
        services.flood = {
            enable = true;
            port = 3001;
            host = "127.0.0.1";
            extraArgs = [
                 "-trurl=http://127.0.0.1:9091/transmission/rpc"
            ];
        };
        
        # Register with Traefik
        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "transmission";
                subdomain = cfg.subdomain;
                backendUrl = "http://127.0.0.1:3001";
            }
            {
                name = "transmission-api";
                subdomain = "api.${cfg.subdomain}";
                backendUrl = "http://127.0.0.1:9091";
            }
        ];
    };
}

