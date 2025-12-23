{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.wallos;
in
{
    options.homelab.wallos = {
        enable = mkEnableOption "Wallos subscription tracker";

        subdomain = mkOption {
            type = types.str;
            description = "Subdomain for Wallos";
        };

        port = mkOption {
            type = types.int;
            default = 8282;
            description = "Port for Wallos web interface";
        };

        dataDir = mkOption {
            type = types.path;
            default = "/var/lib/wallos";
            description = "Directory for Wallos data";
        };

        timezone = mkOption {
            type = types.str;
            default = if config.time.timeZone != null then config.time.timeZone else "UTC";
            description = "Timezone for Wallos (defaults to system timezone)";
        };
    };

    config = mkIf cfg.enable {
        systemd.tmpfiles.rules = [
            "d ${cfg.dataDir} 0750 ${config.metadata.user} ${config.metadata.user} -"
            "d ${cfg.dataDir}/db 0750 ${config.metadata.user} ${config.metadata.user} -"
            "d ${cfg.dataDir}/logos 0750 ${config.metadata.user} ${config.metadata.user} -"
        ];

        virtualisation.oci-containers.containers.wallos = {
            image = "bellamy/wallos:latest";
            ports = [ "${toString cfg.port}:80" ];
            volumes = [
                "${cfg.dataDir}/db:/var/www/html/db"
                "${cfg.dataDir}/logos:/var/www/html/images/uploads/logos"
            ];
            environment = {
                TZ = cfg.timezone;
            };
            extraOptions = [
                "--pull=always"
            ];
        };

        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "wallos";
                subdomain = cfg.subdomain;
                backendUrl = "http://127.0.0.1:${toString cfg.port}";
            }
        ];

        homelab.glance.services = mkIf config.homelab.glance.enable [
            {
                title = "Wallos";
                subdomain = cfg.subdomain;
                icon = "mdi:credit-card-clock";
                group = "Services";
            }
        ];
    };
}

