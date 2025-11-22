{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.arr-stack.cleanuparr;
    arrCfg = config.homelab.arr-stack;
in
{
    options.homelab.arr-stack.cleanuparr = {
        enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable Cleanuparr cleanup service";
        };

        subdomain = mkOption {
            type = types.str;
            description = "Subdomain for Cleanuparr";
        };

        port = mkOption {
            type = types.int;
            default = 11011;
            description = "Port for Cleanuparr web interface";
        };

        dataDir = mkOption {
            type = types.path;
            default = "/var/lib/cleanuparr";
            description = "Directory for Cleanuparr data";
        };
    };

    config = mkIf (arrCfg.enable && cfg.enable) {
        systemd.tmpfiles.rules = [
            "d ${cfg.dataDir} 0750 ${config.metadata.user} ${config.metadata.user} -"
        ];

        virtualisation.oci-containers.containers.cleanuparr = {
            image = "ghcr.io/cleanuparr/cleanuparr:latest";
            ports = [ "${toString cfg.port}:11011" ];
            volumes = [
                "${cfg.dataDir}:/config"
            ];
            environment = {
                PORT = "11011";
                BASE_PATH = "";
                PUID = "1000";
                PGID = "100";
                UMASK = "022";
                TZ = "UTC";
            };
            extraOptions = [
                "--pull=always"
            ];
        };

        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "cleanuparr";
                subdomain = cfg.subdomain;
                backendUrl = "http://127.0.0.1:${toString cfg.port}";
            }
        ];
    };
}

