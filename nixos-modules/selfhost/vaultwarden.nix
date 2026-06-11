{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.vaultwarden;
    runtimeEnv = "/run/vaultwarden/env";
in
{
    options.homelab.vaultwarden = {
        enable = mkEnableOption "Vaultwarden password manager";

        subdomain = mkOption {
            type = types.str;
            description = ''
                Subdomain for Vaultwarden (e.g. "vault" for public vault.$DOMAIN,
                or "vault.vps.local" for VPN-only access).
            '';
        };

        port = mkOption {
            type = types.int;
            default = 8081;
            description = "Local port for Vaultwarden HTTP (bound to localhost only)";
        };

        dataDir = mkOption {
            type = types.path;
            default = "/var/lib/vaultwarden";
            description = "Directory for Vaultwarden data (SQLite DB, attachments)";
        };

        signupsAllowed = mkOption {
            type = types.bool;
            default = false;
            description = "Allow new account registration (keep false for a private instance)";
        };

        invitationsAllowed = mkOption {
            type = types.bool;
            default = true;
            description = "Allow inviting new users via the admin panel";
        };

        rateLimit = mkOption {
            type = types.bool;
            default = true;
            description = "Apply Traefik rate limiting to the Vaultwarden route";
        };
    };

    config = mkIf cfg.enable {
        sops.secrets = {
            domain = {
                sopsFile = ../../secrets/shared/selfhost.yaml;
            };
            vaultwarden_env = {
                sopsFile = ../../secrets/shared/selfhost.yaml;
            };
        };

        systemd.tmpfiles.rules = [
            "d /run/vaultwarden 0750 root root -"
        ];

        systemd.services.vaultwarden-env = {
            description = "Generate Vaultwarden runtime environment";
            wantedBy = [ "multi-user.target" ];
            before = [ "vaultwarden.service" ];
            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
            };
            script = ''
                DOMAIN_BASE=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.domain.path})
                ${pkgs.coreutils}/bin/cat > ${runtimeEnv} <<EOF
                DOMAIN=https://${cfg.subdomain}.$DOMAIN_BASE
                EOF
            '';
        };

        services.vaultwarden = {
            enable = true;
            config = {
                DATA_FOLDER = toString cfg.dataDir;
                ROCKET_ADDRESS = "127.0.0.1";
                ROCKET_PORT = cfg.port;
                ENABLE_WEBSOCKET = true;
                SIGNUPS_ALLOWED = cfg.signupsAllowed;
                INVITATIONS_ALLOWED = cfg.invitationsAllowed;
            };
            environmentFile = [
                runtimeEnv
                config.sops.secrets.vaultwarden_env.path
            ];
        };

        systemd.services.vaultwarden = {
            after = [ "vaultwarden-env.service" ];
            requires = [ "vaultwarden-env.service" ];
        };

        services.traefik.dynamicConfigOptions.http.middlewares = mkIf cfg.rateLimit {
            vaultwarden-ratelimit.rateLimit = {
                average = 10;
                burst = 25;
                period = "1m";
            };
        };

        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "vaultwarden";
                subdomain = cfg.subdomain;
                backendUrl = "http://127.0.0.1:${toString cfg.port}";
                middlewares =
                    if cfg.rateLimit
                    then [ "default-headers" "https-redirect" "vaultwarden-ratelimit" ]
                    else null;
            }
        ];
    };
}
