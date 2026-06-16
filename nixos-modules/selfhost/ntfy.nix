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

        matrixBot = {
            enable = mkOption {
                type = types.bool;
                default = false;
                description = ''
                    Provision the Matrix reminder bot on ntfy (user, token, ACL) from sops.
                    Secrets live under the matrix/ntfy-bot object in sops (see module README in
                    hosts/homelab). No manual ntfy CLI steps required after sops is filled.
                '';
            };

            username = mkOption {
                type = types.str;
                default = "matrix/ntfy-bot";
                description = "ntfy username for the Matrix reminder bot publisher";
            };

            sopsKey = mkOption {
                type = types.str;
                default = "matrix/ntfy-bot";
                description = ''
                    Sops object prefix for bot secrets. VPS uses matrix/ntfy-bot/password and
                    matrix/ntfy-bot/acl from secrets/hosts/<hostname>.yaml; matrix/ntfy-bot/token
                    from secrets/shared/selfhost.yaml.
                '';
            };
        };
    };

    config = mkIf cfg.enable (let
        rateLimitEnabled = if cfg.rateLimit != null then cfg.rateLimit else isPublic;
        fail2banEnabled = if cfg.fail2ban.enable != null then cfg.fail2ban.enable else isPublic;
        matrixBotEnabled = cfg.matrixBot.enable && isPublic;
        mb = cfg.matrixBot.sopsKey;
        passwordSecret =
            if matrixBotEnabled
            then config.sops.secrets."${mb}/password"
            else null;
        tokenSecret =
            if matrixBotEnabled
            then config.sops.secrets."${mb}/token"
            else null;
        aclSecret =
            if matrixBotEnabled
            then config.sops.secrets."${mb}/acl"
            else null;
    in {
        sops.secrets.domain = {
            sopsFile = ../../secrets/shared/selfhost.yaml;
        };

        sops.secrets."${mb}/password" = mkIf matrixBotEnabled {
            sopsFile = ../../secrets/hosts/${config.metadata.hostName}.yaml;
        };

        sops.secrets."${mb}/token" = mkIf matrixBotEnabled {
            sopsFile = ../../secrets/shared/selfhost.yaml;
        };

        sops.secrets."${mb}/acl" = mkIf matrixBotEnabled {
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
                ${pkgs.coreutils}/bin/cat > ${runtimeEnv} <<EOF
                NTFY_BASE_URL=https://${cfg.subdomain}.$DOMAIN_BASE
                EOF
                ${optionalString matrixBotEnabled ''
                PASSWORD=$(${pkgs.coreutils}/bin/cat ${passwordSecret.path})
                TOKEN=$(${pkgs.coreutils}/bin/tr -d '[:space:]' < ${tokenSecret.path})
                case "$TOKEN" in
                    tk_?????????????????????????????)
                        ;;
                    *)
                        echo "ntfy-env: invalid ${mb}/token (need tk_ + 29 chars)" >&2
                        exit 1
                        ;;
                esac
                case "$PASSWORD" in
                    ""|CHANGE_ME*|change_me*)
                        echo "ntfy-env: set a real password in sops (${mb}/password)" >&2
                        exit 1
                        ;;
                esac
                HASH=$(
                    printf '%s\n%s\n' "$PASSWORD" "$PASSWORD" \
                        | ${pkgs.ntfy-sh}/bin/ntfy user hash \
                        | ${pkgs.coreutils}/bin/tail -n1
                )
                ACL=$(${pkgs.gawk}/bin/gawk '
                    /^[[:space:]]*#/ { next }
                    /^[[:space:]]*$/ { next }
                    {
                        gsub(/^[[:space:]]+|[[:space:]]+$/, "");
                        n = split($0, parts, /[[:space:]]+/);
                        if (n >= 3) {
                            entry = parts[1] ":" parts[2] ":" parts[3];
                            if (out != "") out = out ",";
                            out = out entry;
                        }
                    }
                    END { print out }
                ' ${aclSecret.path})
                ${pkgs.coreutils}/bin/cat >> ${runtimeEnv} <<EOF
                NTFY_AUTH_USERS=${cfg.matrixBot.username}:$HASH:user
                NTFY_AUTH_TOKENS=${cfg.matrixBot.username}:$TOKEN:matrix-reminder-bot
                NTFY_AUTH_ACCESS=$ACL
                EOF
                ''}
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
