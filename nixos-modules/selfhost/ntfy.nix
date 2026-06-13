{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.ntfy;
    runtimeEnv = "/run/ntfy/env";

    isPublic = builtins.match ".*\\.local$" cfg.subdomain == null;
in
{
    options.homelab.ntfy = {
        enable = mkEnableOption "ntfy-sh push notification service";

        subdomain = mkOption {
            type = types.str;
            description = ''
                Subdomain for ntfy (e.g. "ntfy" for public ntfy.$DOMAIN,
                or "ntfy.vm.local" for VPN-only access).
            '';
        };

        port = mkOption {
            type = types.int;
            default = 8089;
            description = "Local port for ntfy HTTP (bound to localhost only)";
        };

        enableWebPush = mkOption {
            type = types.bool;
            default = false;
            description = "Enable web push notifications (requires VAPID keys setup)";
        };

        rateLimit = mkOption {
            type = types.nullOr types.bool;
            default = null;
            description = ''
                Apply Traefik rate limiting to the ntfy route.
                Null auto-enables for public subdomains (not ending in .local).
            '';
        };

        fail2ban = {
            enable = mkOption {
                type = types.nullOr types.bool;
                default = null;
                description = ''
                    Ban repeated failed logins via Traefik access logs.
                    Null auto-enables for public subdomains (not ending in .local).
                '';
            };
        };

        unifiedPush = {
            enable = mkOption {
                type = types.nullOr types.bool;
                default = null;
                description = ''
                    Configure ACLs for UnifiedPush / Matrix push topics (up* prefix).
                    Null auto-enables for public subdomains (not ending in .local).
                '';
            };

            subscriberUsersSopsKey = mkOption {
                type = types.str;
                default = "ntfy/unified-push-subscribers";
                description = ''
                    Sops secret (one ntfy username per line) for logged-in UnifiedPush
                    subscribers. Each user gets read-only access to up* topics.
                    Stored in secrets/hosts/<hostname>.yaml (encrypted).
                '';
            };
        };
    };

    config = mkIf cfg.enable (let
        rateLimitEnabled = if cfg.rateLimit != null then cfg.rateLimit else isPublic;
        fail2banEnabled = if cfg.fail2ban.enable != null then cfg.fail2ban.enable else isPublic;
        unifiedPushEnabled =
            if cfg.unifiedPush.enable != null
            then cfg.unifiedPush.enable
            else isPublic;

        subscriberUsersSecret =
            if unifiedPushEnabled
            then config.sops.secrets.${cfg.unifiedPush.subscriberUsersSopsKey}
            else null;
    in {
        sops.secrets.domain = {
            sopsFile = ../../secrets/shared/selfhost.yaml;
        };

        sops.secrets.${cfg.unifiedPush.subscriberUsersSopsKey} = mkIf unifiedPushEnabled {
            sopsFile = ../../secrets/hosts/${config.metadata.hostName}.yaml;
        };

        systemd.tmpfiles.rules = [
            "d /run/ntfy 0750 root root -"
        ];

        systemd.services.ntfy-env = {
            description = "Generate ntfy runtime environment";
            wantedBy = [ "multi-user.target" ];
            before = [ "ntfy-sh.service" ];
            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
            };
            script = ''
                DOMAIN_BASE=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.domain.path})
                AUTH_ACCESS='*:up*:rw'
                ${optionalString unifiedPushEnabled ''
                while IFS= read -r user || [ -n "$user" ]; do
                    user=$(printf '%s' "$user" | ${pkgs.gnused}/bin/sed 's/[[:space:]]//g')
                    [ -z "$user" ] && continue
                    [ "''${user#\#}" != "$user" ] && continue
                    AUTH_ACCESS="$AUTH_ACCESS,$user:up*:ro"
                done < ${subscriberUsersSecret.path}
                ''}
                ${pkgs.coreutils}/bin/cat > ${runtimeEnv} <<EOF
                NTFY_BASE_URL=https://${cfg.subdomain}.$DOMAIN_BASE
                NTFY_AUTH_ACCESS=$AUTH_ACCESS
                EOF
            '';
        };

        services.ntfy-sh = {
            enable = true;
            environmentFile = runtimeEnv;
            settings = {
                listen-http = "127.0.0.1:${toString cfg.port}";
                # Overridden at runtime via ntfy-env.service (NTFY_BASE_URL).
                base-url = "http://127.0.0.1:${toString cfg.port}";
                behind-proxy = true;
                cache-file = "/var/lib/ntfy-sh/cache.db";
                auth-file = "/var/lib/ntfy-sh/auth.db";
                attachment-cache-dir = "/var/lib/ntfy-sh/attachments";
            } // optionalAttrs isPublic {
                auth-default-access = "deny-all";
                enable-login = true;
                enable-signup = false;
            } // optionalAttrs cfg.enableWebPush {
                web-push-file = "/var/lib/ntfy-sh/webpush.db";
            };
        };

        systemd.services.ntfy-sh = {
            after = [ "ntfy-env.service" ];
            requires = [ "ntfy-env.service" ];
        };

        services.traefik.dynamicConfigOptions.http.middlewares = mkIf rateLimitEnabled {
            ntfy-ratelimit.rateLimit = {
                average = 30;
                burst = 60;
                period = "1m";
            };
        };

        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "ntfy";
                subdomain = cfg.subdomain;
                backendUrl = "http://127.0.0.1:${toString cfg.port}";
                middlewares =
                    if rateLimitEnabled
                    then [ "default-headers" "https-redirect" "ntfy-ratelimit" ]
                    else null;
            }
        ];

        homelab.fail2ban.jails = mkIf (fail2banEnabled && config.homelab.fail2ban.enable) [
            {
                name = "ntfy-auth";
                traefik = {
                    host = cfg.subdomain;
                    pathPrefixes = [ "/v1/account" ];
                    methods = [ "POST" ];
                    statusCodes = [ 401 403 ];
                };
                settings = {
                    maxretry = 5;
                    findtime = "10m";
                    bantime = "1h";
                };
            }
        ];

        homelab.glance.services = mkIf config.homelab.glance.enable [
            {
                title = "Ntfy";
                subdomain = cfg.subdomain;
                icon = "mdi:bell-ring";
                group = "Other";
            }
        ];
    });
}
