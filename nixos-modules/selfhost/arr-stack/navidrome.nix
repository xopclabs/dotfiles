{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.arr-stack.navidrome;
    arrCfg = config.homelab.arr-stack;
    arrProxyEnvFile = "/run/arr-proxy.env";
in
{
    options.homelab.arr-stack.navidrome = {
        enable = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Enable [Navidrome](https://www.navidrome.org/) Subsonic-compatible music streaming server.
            '';
        };

        openFirewall = mkEnableOption "Open firewall for Navidrome";

        proxy = mkOption {
            type = types.bool;
            default = true;
            description = "Route Navidrome outbound traffic through xray proxy (arr-proxy-env).";
        };

        subdomain = mkOption {
            type = types.str;
            description = "Subdomain for Navidrome (Traefik).";
        };

        port = mkOption {
            type = types.port;
            default = 4533;
            description = "Listen address is localhost; Traefik serves HTTPS on this upstream port.";
        };

        musicDir = mkOption {
            type = types.path;
            default = config.metadata.selfhost.storage.media.musicDir;
            description = "Music library root (`MusicFolder`).";
        };

        settings = mkOption {
            type = (pkgs.formats.json { }).type;
            default = { };
            description = ''
              Extra Navidrome settings merged after defaults.
              See <https://www.navidrome.org/docs/usage/configuration-options/>.
            '';
        };
    };

    config = mkIf (arrCfg.enable && cfg.enable) {
        services.navidrome = {
            enable = true;
            group = "users";
            openFirewall = cfg.openFirewall;
            settings = recursiveUpdate {
                Address = "127.0.0.1";
                Port = cfg.port;
                MusicFolder = toString cfg.musicDir;
            } cfg.settings;
        };

        systemd.services.navidrome = mkMerge [
            {
                serviceConfig.RequiresMountsFor = [ cfg.musicDir ];
            }
            (mkIf cfg.proxy {
                after = [ "arr-proxy-env.service" ];
                requires = [ "arr-proxy-env.service" ];
                serviceConfig.EnvironmentFile = arrProxyEnvFile;
            })
        ];

        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "navidrome";
                subdomain = cfg.subdomain;
                backendUrl = "http://127.0.0.1:${toString cfg.port}";
            }
        ];

        homelab.glance.services = mkIf config.homelab.glance.enable [
            {
                title = "Navidrome";
                subdomain = cfg.subdomain;
                icon = "mdi:music-circle";
                group = "*arr";
                priority = 3;
            }
        ];
    };
}
