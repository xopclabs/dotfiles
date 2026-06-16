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
                default = "matrix-bot";
                description = "ntfy username for the Matrix reminder bot publisher";
            };

            sharedSopsKey = mkOption {
                type = types.str;
                default = "matrix/ntfy-bot";
                description = ''
                    Sops prefix on secrets/shared/selfhost.yaml for matrix/ntfy-bot/token.
                '';
            };

            hostSopsKey = mkOption {
                type = types.str;
                default = "ntfy/matrix-bot";
                description = ''
                    Sops prefix on secrets/hosts/<hostname>.yaml for password and acl
                    (ntfy.matrix-bot in the YAML file).
                '';
            };

            subscribersSopsKey = mkOption {
                type = types.str;
                default = "ntfy/subscribers";
                description = ''
                    Multiline sops secret on secrets/hosts/<hostname>.yaml with one
                    username:password per line (family ntfy accounts for topic ACL).
                '';
            };

            adminSubscribers = mkOption {
                type = types.listOf types.str;
                default = [ "pavel" ];
                description = ''
                    ntfy subscriber usernames provisioned with the admin role (full access,
                    no per-topic ACL entries needed).
                '';
            };
        };
    };

    config = mkIf cfg.enable (let
        rateLimitEnabled = if cfg.rateLimit != null then cfg.rateLimit else isPublic;
        fail2banEnabled = if cfg.fail2ban.enable != null then cfg.fail2ban.enable else isPublic;
        matrixBotEnabled = cfg.matrixBot.enable && isPublic;
        sharedMb = cfg.matrixBot.sharedSopsKey;
        hostMb = cfg.matrixBot.hostSopsKey;
        passwordSecret =
            if matrixBotEnabled
            then config.sops.secrets."${hostMb}/password"
            else null;
        tokenSecret =
            if matrixBotEnabled
            then config.sops.secrets."${sharedMb}/token"
            else null;
        aclSecret =
            if matrixBotEnabled
            then config.sops.secrets."${hostMb}/acl"
            else null;
        subscribersSecret =
            if matrixBotEnabled
            then config.sops.secrets."${cfg.matrixBot.subscribersSopsKey}"
            else null;
    in {
        sops.secrets.domain = {
            sopsFile = ../../secrets/shared/selfhost.yaml;
        };

        sops.secrets."${hostMb}/password" = mkIf matrixBotEnabled {
            sopsFile = ../../secrets/hosts/${config.metadata.hostName}.yaml;
        };

        sops.secrets."${sharedMb}/token" = mkIf matrixBotEnabled {
            sopsFile = ../../secrets/shared/selfhost.yaml;
        };

        sops.secrets."${hostMb}/acl" = mkIf matrixBotEnabled {
            sopsFile = ../../secrets/hosts/${config.metadata.hostName}.yaml;
        };

        sops.secrets."${cfg.matrixBot.subscribersSopsKey}" = mkIf matrixBotEnabled {
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
                        echo "ntfy-env: invalid ${sharedMb}/token (need tk_ + 29 chars)" >&2
                        exit 1
                        ;;
                esac
                case "$PASSWORD" in
                    ""|CHANGE_ME*|change_me*)
                        echo "ntfy-env: set a real password in sops (${hostMb}/password)" >&2
                        exit 1
                        ;;
                esac
                HASH=$(
                    printf '%s\n%s\n' "$PASSWORD" "$PASSWORD" \
                        | ${pkgs.ntfy-sh}/bin/ntfy user hash \
                        | ${pkgs.coreutils}/bin/tail -n1
                )
                SUBSCRIBER_USERS=""
                while IFS= read -r line || [ -n "$line" ]; do
                    line=$(${pkgs.gnused}/bin/sed 's/^[[:space:]]*//;s/[[:space:]]*$//' <<< "$line")
                    [ -z "$line" ] && continue
                    case "$line" in \#*) continue ;; esac
                    user=$(${pkgs.gnused}/bin/sed 's/:.*$//' <<< "$line")
                    pass=$(${pkgs.gnused}/bin/sed 's/^[^:]*://' <<< "$line")
                    if [ -z "$user" ] || [ -z "$pass" ]; then
                        echo "ntfy-env: invalid subscriber line (need user:password): $line" >&2
                        exit 1
                    fi
                    case "$pass" in
                        ""|CHANGE_ME*|change_me*)
                            echo "ntfy-env: set a real password for subscriber $user in sops (${cfg.matrixBot.subscribersSopsKey})" >&2
                            exit 1
                            ;;
                    esac
                    sub_hash=$(
                        printf '%s\n%s\n' "$pass" "$pass" \
                            | ${pkgs.ntfy-sh}/bin/ntfy user hash \
                            | ${pkgs.coreutils}/bin/tail -n1
                    )
                    role=user
                    ${concatMapStringsSep "\n" (u: ''
                      if [ "$user" = "${u}" ]; then role=admin; fi
                    '') cfg.matrixBot.adminSubscribers}
                    entry="$user:$sub_hash:$role"
                    if [ -z "$SUBSCRIBER_USERS" ]; then
                        SUBSCRIBER_USERS="$entry"
                    else
                        SUBSCRIBER_USERS="$SUBSCRIBER_USERS,$entry"
                    fi
                done < ${subscribersSecret.path}
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
                NTFY_AUTH_USERS=$(
                    if [ -n "$SUBSCRIBER_USERS" ]; then
                        echo "${cfg.matrixBot.username}:$HASH:user,$SUBSCRIBER_USERS"
                    else
                        echo "${cfg.matrixBot.username}:$HASH:user"
                    fi
                )
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
