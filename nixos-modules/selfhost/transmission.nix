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
                rpc-username = "admin";
                rpc-password = "{324aa5bb38e744cbed04fd177329c89fbb3a64101fqYtEbt";
                rpc-authentication-required = true;
            };
        };
        
        # Create necessary directories
        systemd.tmpfiles.rules = [
            "d ${config.metadata.selfhost.storage.downloads.otherDir} 0775 transmission transmission -"
            "d ${config.metadata.selfhost.storage.downloads.incompleteDir} 0775 transmission transmission -"
        ];
        
        # Register with Traefik
        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "transmission";
                subdomain = cfg.subdomain;
                backendUrl = "http://127.0.0.1:${toString config.services.transmission.settings.rpc-port}";
            }
        ];
    };
}

