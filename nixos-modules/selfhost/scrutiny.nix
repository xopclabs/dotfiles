{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.scrutiny;
in
{
    options.homelab.scrutiny = {
        enable = mkEnableOption "Scrutiny hard drive health monitoring";

        subdomain = mkOption {
            type = types.str;
            description = "Subdomain for Scrutiny web UI";
        };

        port = mkOption {
            type = types.port;
            default = 8081;
            description = "Port for Scrutiny web server";
        };

        collectorInterval = mkOption {
            type = types.str;
            default = "0 0 * * *";
            description = "Cron schedule for SMART data collection (default: daily at midnight)";
        };

        devices = mkOption {
            type = types.listOf types.str;
            default = [];
            example = [ "/dev/sda" "/dev/sdb" "/dev/nvme0" ];
            description = "List of devices to monitor. Empty list means auto-detect all drives.";
        };
    };
    
    config = mkIf cfg.enable {
        # Enable smartmontools for SMART data
        services.smartd = {
            enable = true;
            autodetect = true;
            defaults.autodetected = "-a -o on -S on -n standby,q -s (S/../.././02|L/../../6/03) -W 4,35,45";
            notifications = {
                wall.enable = true;
                mail.enable = false;
            };
        };

        # Scrutiny web UI and collector
        services.scrutiny = {
            enable = true;
            
            settings = {
                web = {
                    listen = {
                        host = "127.0.0.1";
                        port = cfg.port;
                    };
                };
            };

            collector = {
                enable = true;
                schedule = cfg.collectorInterval;
                settings = {
                    host.id = config.networking.hostName;
                } // (if cfg.devices != [] then {
                    devices = map (dev: { device = dev; }) cfg.devices;
                } else {});
            };
        };

        # Register with Traefik
        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "scrutiny";
                subdomain = cfg.subdomain;
                backendUrl = "http://127.0.0.1:${toString cfg.port}";
            }
        ];

        # Register with Glance dashboard
        homelab.glance.services = mkIf config.homelab.glance.enable [
            {
                title = "Scrutiny";
                subdomain = cfg.subdomain;
                icon = "mdi:harddisk";
                group = "Other";
            }
        ];
    };
}

