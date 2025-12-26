{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.calibre-web;
in
{
    options.homelab.calibre-web = {
        enable = mkEnableOption "Calibre-Web ebook management";

        subdomain = mkOption {
            type = types.str;
            description = "Subdomain for Calibre-Web";
        };

        port = mkOption {
            type = types.int;
            default = 8083;
            description = "Port for Calibre-Web web interface";
        };

        libraryDir = mkOption {
            type = types.path;
            default = "/var/lib/calibre-web/library";
            description = "Path to Calibre library directory";
        };

        enableBookConversion = mkOption {
            type = types.bool;
            default = true;
            description = "Enable ebook format conversion using Calibre";
        };

        enableBookUploading = mkOption {
            type = types.bool;
            default = true;
            description = "Allow uploading books via the web UI";
        };
    };

    config = mkIf cfg.enable {

        services.calibre-web = {
            enable = true;
            listen = {
                ip = "127.0.0.1";
                port = cfg.port;
            };
            options = {
                calibreLibrary = cfg.libraryDir;
                enableBookConversion = cfg.enableBookConversion;
                enableBookUploading = cfg.enableBookUploading;
            };
        };

        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "calibre-web";
                subdomain = cfg.subdomain;
                backendUrl = "http://127.0.0.1:${toString cfg.port}";
            }
        ];

        homelab.glance.services = mkIf config.homelab.glance.enable [
            {
                title = "Calibre";
                subdomain = cfg.subdomain;
                icon = "mdi:bookshelf";
                group = "Services";
            }
        ];
    };
}

