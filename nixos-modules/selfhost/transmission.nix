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
                download-dir = config.metadata.selfhost.storage.downloads.mainDir;
                incomplete-dir-enabled = false;
                
                rpc-enabled = true;
                rpc-port = 9091;
                rpc-bind-address = "127.0.0.1";
                rpc-username = "admin";
                rpc-password = "{324aa5bb38e744cbed04fd177329c89fbb3a64101fqYtEbt";
                rpc-authentication-required = true;
            };
        };
        
        # Create necessary directories for downloads
        systemd.tmpfiles.rules = [
            "d ${config.metadata.selfhost.storage.downloads.mainDir} 0777 ${config.metadata.user} ${config.metadata.user} -"
            "d ${config.metadata.selfhost.storage.downloads.moviesDir} 0777 ${config.metadata.user} ${config.metadata.user} -"
            "d ${config.metadata.selfhost.storage.downloads.tvDir} 0777 ${config.metadata.user} ${config.metadata.user} -"
            "d ${config.metadata.selfhost.storage.downloads.musicDir} 0777 ${config.metadata.user} ${config.metadata.user} -"
        ];
        
        # Register with Traefik
        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "transmission";
                subdomain = cfg.subdomain;
                backendUrl = "http://127.0.0.1:${toString config.services.transmission.settings.rpc-port}";
            }
        ];

        # Register with Glance dashboard
        homelab.glance.services = mkIf config.homelab.glance.enable [
            {
                title = "Transmission";
                subdomain = cfg.subdomain;
                icon = "si:transmission";
                group = "*arr";
                priority = 1;
                altStatusCodes = [ 401 403];
            }
        ];
    };
}

