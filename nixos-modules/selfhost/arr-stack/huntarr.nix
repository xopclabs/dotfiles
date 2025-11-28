{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.arr-stack.huntarr;
    arrCfg = config.homelab.arr-stack;
in
{
    options.homelab.arr-stack.huntarr = {
        enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable Huntarr missing content hunter";
        };

        subdomain = mkOption {
            type = types.str;
            description = "Subdomain for Huntarr";
        };

        port = mkOption {
            type = types.int;
            default = 9705;
            description = "Port for Huntarr web interface";
        };

        dataDir = mkOption {
            type = types.path;
            default = "/var/lib/huntarr";
            description = "Directory for Huntarr data";
        };
    };

    config = mkIf (arrCfg.enable && cfg.enable) {
        systemd.tmpfiles.rules = [
            "d ${cfg.dataDir} 0750 ${config.metadata.user} ${config.metadata.user} -"
        ];

        virtualisation.oci-containers.containers.huntarr = {
            image = "ghcr.io/plexguide/huntarr:latest";
            ports = [ "${toString cfg.port}:9705" ];
            volumes = [
                "${cfg.dataDir}:/config"
            ];
            environment = {
                PUID = "1000";
                PGID = "100";
                TZ = "UTC";
            };
            extraOptions = [
                "--pull=always"
            ];
        };

        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "huntarr";
                subdomain = cfg.subdomain;
                backendUrl = "http://127.0.0.1:${toString cfg.port}";
            }
        ];

        homelab.glance.services = mkIf config.homelab.glance.enable [
            {
                title = "Huntarr";
                subdomain = cfg.subdomain;
                icon = "mdi:magnify";
                group = "*arr";
                priority = 1002;
            }
        ];
    };
}

