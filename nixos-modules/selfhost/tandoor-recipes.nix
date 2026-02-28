{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.tandoor-recipes;
in
{
    options.homelab.tandoor-recipes = {
        enable = mkEnableOption "Tandoor Recipes meal planning and recipe management";

        subdomain = mkOption {
            type = types.str;
            description = "Subdomain for Tandoor Recipes";
        };

        port = mkOption {
            type = types.int;
            default = 8099;
            description = "Port for Tandoor Recipes web interface";
        };

        address = mkOption {
            type = types.str;
            default = "127.0.0.1";
            description = "Address for Tandoor Recipes to listen on";
        };
    };

    config = mkIf cfg.enable {
        homelab.postgres = {
            enable = true;
            databases = [ "tandoor_recipes" ];
            ensureUsers = [
                {
                    name = "tandoor_recipes";
                    ensureDBOwnership = true;
                }
            ];
        };

        services.tandoor-recipes = {
            enable = true;
            address = cfg.address;
            port = cfg.port;

            database.createLocally = false;

            extraConfig = {
                DB_ENGINE = "django.db.backends.postgresql";
                POSTGRES_HOST = "/run/postgresql";
                POSTGRES_USER = "tandoor_recipes";
                POSTGRES_DB = "tandoor_recipes";
            };
        };

        systemd.services.tandoor-recipes = {
            after = [ "postgresql.service" ];
            requires = [ "postgresql.service" ];
        };

        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "tandoor-recipes";
                subdomain = cfg.subdomain;
                backendUrl = "http://${cfg.address}:${toString cfg.port}";
            }
        ];

        homelab.glance.services = mkIf config.homelab.glance.enable [
            {
                title = "Tandoor Recipes";
                subdomain = cfg.subdomain;
                icon = "mdi:silverware-fork-knife";
                group = "Services";
            }
        ];
    };
}
