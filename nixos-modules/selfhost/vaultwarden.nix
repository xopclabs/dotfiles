{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.vaultwarden;
    runtimeEnv = "/run/vaultwarden/env";
    backendUrl = "http://127.0.0.1:${toString cfg.port}";
    mtlsDir = cfg.mtls.dataDir;
    mtlsPublic = "${mtlsDir}/public";
    mtlsCa = "${mtlsDir}/ca.crt";
    mtlsP12 = "${mtlsPublic}/client.p12";
    # Must live under mtlsDir so the traefik user can read it (group traefik).
    mtlsUsersFile = "${mtlsDir}/users";
    mtlsDownloadSubdomain =
        if cfg.mtls.downloadSubdomain != null
        then cfg.mtls.downloadSubdomain
        else "${cfg.subdomain}-cert";
    vaultMiddlewares =
        [ "default-headers" "https-redirect" ]
        ++ optional cfg.rateLimit "vaultwarden-ratelimit";
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

        admin = {
            restrict = mkOption {
                type = types.bool;
                default = true;
                description = ''
                    Serve /admin from a dedicated Traefik router that only accepts `admin.allowedRanges`.
                    The rest of the vault stays reachable from anywhere.
                '';
            };

            allowedRanges = mkOption {
                type = types.listOf types.str;
                default = optional config.homelab.wireguard.enable config.homelab.wireguard.subnet;
                example = [ "10.13.13.0/24" ];
                description = ''
                    Source ranges permitted to reach /admin.
                    Defaults to the WireGuard subnet, so the panel is VPN-only.
                '';
            };
        };

        mtls = {
            enable = mkEnableOption ''
                Require a client certificate (mTLS) for Vaultwarden.
                Break-glass .p12 download is on a separate subdomain (see downloadSubdomain)
                because Traefik cannot mix mTLS and non-mTLS TLS options on the same Host.
            '';

            dataDir = mkOption {
                type = types.path;
                default = "/var/lib/vaultwarden-mtls";
                description = "Directory for the generated CA, client certificate, and downloadable .p12";
            };

            listenPort = mkOption {
                type = types.port;
                default = 8091;
                description = "Local port for the static .p12 download server";
            };

            downloadSubdomain = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = ''
                    Public subdomain for the basic-auth .p12 download (no client cert).
                    Defaults to `<subdomain>-cert` (e.g. salt-cert). Must be a different
                    hostname than `subdomain` — Traefik TLS options are per-Host, not per-path.
                '';
            };

            usernameSopsKey = mkOption {
                type = types.str;
                default = "vaultwarden/mtls/username";
                description = "Sops key on secrets/hosts/<hostname>.yaml for the cert-download basic-auth username.";
            };

            passwordHashSopsKey = mkOption {
                type = types.str;
                default = "vaultwarden/mtls/password-hash";
                description = ''
                    Sops key holding a salted password hash for cert-download basic-auth (htpasswd bcrypt).
                    Generate with: `htpasswd -nbB USER PASS` and store only the `$2y$...` part
                    (or the full `USER:$2y$...` line — the username field is ignored if present).
                '';
            };

            p12PassphraseSopsKey = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = ''
                    Optional sops key for a PKCS#12 export passphrase (plaintext).
                    `null` (default) or an empty secret value = passwordless .p12
                    (leave blank on import). Set e.g. `"vaultwarden/mtls/p12-passphrase"`
                    only if you want the private key encrypted inside the file.
                '';
            };
        };

        fail2ban = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Ban repeated failed logins and admin probes via Traefik access logs";
            };
        };

        backup = {
            enable = mkEnableOption "BorgBackup of Vaultwarden data to a remote repository";

            dir = mkOption {
                type = types.str;
                default = "/var/backup/vaultwarden";
                description = ''
                    Local directory where Vaultwarden writes consistent SQLite
                    snapshots before Borg uploads them (services.vaultwarden.backupDir).
                '';
            };

            repo = mkOption {
                type = types.str;
                description = "Borg repository URL (e.g. ssh://user@host/./repo)";
            };

            schedule = mkOption {
                type = types.str;
                default = "daily";
                description = "Systemd calendar expression for the Borg backup timer";
            };

            prune = {
                keep = {
                    daily = mkOption {
                        type = types.nullOr types.int;
                        default = 7;
                    };
                    weekly = mkOption {
                        type = types.nullOr types.int;
                        default = 4;
                    };
                    monthly = mkOption {
                        type = types.nullOr types.int;
                        default = 6;
                    };
                };
            };
        };
    };

    config = mkIf cfg.enable {
        assertions = [
            {
                assertion = cfg.admin.restrict -> cfg.admin.allowedRanges != [ ];
                message = ''
                    homelab.vaultwarden.admin.restrict is enabled but admin.allowedRanges is empty, which Traefik rejects.
                    Enable homelab.wireguard or set the ranges explicitly.
                '';
            }
            {
                assertion = cfg.mtls.enable -> config.homelab.traefik.enable;
                message = "homelab.vaultwarden.mtls.enable requires homelab.traefik.enable (mTLS is enforced at Traefik).";
            }
            {
                assertion = cfg.mtls.enable -> mtlsDownloadSubdomain != cfg.subdomain;
                message = "homelab.vaultwarden.mtls.downloadSubdomain must differ from subdomain (Traefik cannot mix mTLS TLS options on one Host).";
            }
        ];

        sops.secrets = {
            domain = {
                sopsFile = ../../secrets/shared/selfhost.yaml;
            };
            vaultwarden_env = {
                sopsFile = ../../secrets/shared/selfhost.yaml;
            };
            "${cfg.mtls.usernameSopsKey}" = mkIf cfg.mtls.enable {
                sopsFile = ../../secrets/hosts/${config.metadata.hostName}.yaml;
                restartUnits = [ "vaultwarden-mtls-certs.service" ];
            };
            "${cfg.mtls.passwordHashSopsKey}" = mkIf cfg.mtls.enable {
                sopsFile = ../../secrets/hosts/${config.metadata.hostName}.yaml;
                restartUnits = [ "vaultwarden-mtls-certs.service" ];
            };
        } // optionalAttrs (cfg.mtls.enable && cfg.mtls.p12PassphraseSopsKey != null) {
            "${cfg.mtls.p12PassphraseSopsKey}" = {
                sopsFile = ../../secrets/hosts/${config.metadata.hostName}.yaml;
                # Oneshot won't re-run on secret content changes otherwise — stale .p12 keeps the old passphrase.
                restartUnits = [ "vaultwarden-mtls-certs.service" ];
            };
        };

        systemd.tmpfiles.rules = [
            "d /run/vaultwarden 0750 root root -"
        ] ++ optionals cfg.mtls.enable [
            "d ${mtlsDir} 0750 root traefik -"
            "d ${mtlsPublic} 0755 root root -"
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
                ${optionalString cfg.mtls.enable "EXPERIMENTAL_CLIENT_FEATURE_FLAGS=mutual-tls"}
                EOF
            '';
        };

        # Generate CA + client .p12 once; regenerate the .p12 when the passphrase changes.
        systemd.services.vaultwarden-mtls-certs = mkIf cfg.mtls.enable {
            description = "Generate Vaultwarden mTLS CA and client certificate";
            wantedBy = [ "multi-user.target" ];
            before = [ "traefik.service" "vaultwarden-mtls-download.service" ];
            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
            };
            path = [ pkgs.openssl pkgs.coreutils ];
            script = ''
                set -euo pipefail
                USER=$(tr -d '\n' < ${config.sops.secrets."${cfg.mtls.usernameSopsKey}".path})
                HASH=$(tr -d '\n' < ${config.sops.secrets."${cfg.mtls.passwordHashSopsKey}".path})
                ${if cfg.mtls.p12PassphraseSopsKey == null then ''
                P12_PASS=
                '' else ''
                P12_PASS=$(tr -d '\n' < ${config.sops.secrets."${cfg.mtls.p12PassphraseSopsKey}".path})
                ''}

                case "$USER" in
                    ""|CHANGE_ME*|change_me*)
                        echo "vaultwarden-mtls: set a real username in sops (${cfg.mtls.usernameSopsKey})" >&2
                        exit 1
                        ;;
                esac
                case "$HASH" in
                    \$2[aby]\$*|\$apr1\$*|\$2y\$*)
                        ;;
                    *:\$2[aby]\$*|*:\$apr1\$*|*:\$2y\$*)
                        # Full htpasswd line — keep only the hash.
                        HASH=''${HASH#*:}
                        ;;
                    ""|CHANGE_ME*|change_me*)
                        echo "vaultwarden-mtls: set a bcrypt htpasswd hash in sops (${cfg.mtls.passwordHashSopsKey})" >&2
                        exit 1
                        ;;
                    *)
                        echo "vaultwarden-mtls: ${cfg.mtls.passwordHashSopsKey} must be a salted htpasswd hash (e.g. \$2y\$...)" >&2
                        exit 1
                        ;;
                esac
                ${optionalString (cfg.mtls.p12PassphraseSopsKey != null) ''
                case "$P12_PASS" in
                    CHANGE_ME*|change_me*)
                        echo "vaultwarden-mtls: replace placeholder PKCS#12 passphrase in sops (${cfg.mtls.p12PassphraseSopsKey})" >&2
                        exit 1
                        ;;
                esac
                ''}

                umask 077
                if [ ! -f ${mtlsDir}/ca.key ] || [ ! -f ${mtlsCa} ]; then
                    openssl genrsa -out ${mtlsDir}/ca.key 4096
                    openssl req -x509 -new -nodes \
                        -key ${mtlsDir}/ca.key -sha256 -days 3650 \
                        -out ${mtlsCa} \
                        -subj "/CN=Vaultwarden mTLS CA"
                    chmod 644 ${mtlsCa}
                fi

                PASS_HASH=$(printf '%s' "$P12_PASS" | sha256sum | cut -d' ' -f1)
                NEED_P12=0
                if [ ! -f ${mtlsP12} ]; then
                    NEED_P12=1
                elif [ ! -f ${mtlsDir}/p12.passhash ] || [ "$(cat ${mtlsDir}/p12.passhash)" != "$PASS_HASH" ]; then
                    NEED_P12=1
                fi

                if [ "$NEED_P12" = 1 ]; then
                    openssl genrsa -out ${mtlsDir}/client.key 2048
                    openssl req -new -key ${mtlsDir}/client.key \
                        -out ${mtlsDir}/client.csr \
                        -subj "/CN=vaultwarden-client"
                    openssl x509 -req -in ${mtlsDir}/client.csr \
                        -CA ${mtlsCa} -CAkey ${mtlsDir}/ca.key -CAcreateserial \
                        -out ${mtlsDir}/client.crt -days 3650 -sha256
                    # env: avoids shell metacharacter breakage in pass:"..."
                    export P12_PASS
                    openssl pkcs12 -export \
                        -out ${mtlsP12} \
                        -inkey ${mtlsDir}/client.key \
                        -in ${mtlsDir}/client.crt \
                        -certfile ${mtlsCa} \
                        -passout env:P12_PASS \
                        -name "vaultwarden-client"
                    chmod 644 ${mtlsP12}
                    printf '%s\n' "$PASS_HASH" > ${mtlsDir}/p12.passhash
                fi

                # Traefik basicAuth users file from sops username + salted hash.
                printf '%s:%s\n' "$USER" "$HASH" > ${mtlsUsersFile}
                chmod 644 ${mtlsUsersFile}
            '';
        };

        systemd.services.vaultwarden-mtls-download = mkIf cfg.mtls.enable {
            description = "Serve Vaultwarden mTLS client certificate for /mtls";
            wantedBy = [ "multi-user.target" ];
            after = [ "vaultwarden-mtls-certs.service" ];
            requires = [ "vaultwarden-mtls-certs.service" ];
            serviceConfig = {
                Type = "simple";
                ExecStart = ''
                    ${pkgs.static-web-server}/bin/static-web-server \
                        --host 127.0.0.1 \
                        --port ${toString cfg.mtls.listenPort} \
                        --root ${mtlsPublic} \
                        --log-level warn
                '';
                Restart = "on-failure";
                RestartSec = "2s";
            };
        };

        services.vaultwarden = {
            enable = true;
            backupDir = mkIf cfg.backup.enable cfg.backup.dir;
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

        # Borg triggers the native backup on demand; skip the built-in timer.
        systemd.timers.backup-vaultwarden.enable = mkIf cfg.backup.enable (mkForce false);

        systemd.services.vaultwarden = {
            after = [ "vaultwarden-env.service" ];
            requires = [ "vaultwarden-env.service" ];
        };

        services.traefik.dynamicConfigOptions = mkMerge [
            {
                http.middlewares = mkMerge [
                    (mkIf cfg.rateLimit {
                        vaultwarden-ratelimit.rateLimit = {
                            average = 10;
                            burst = 25;
                            period = "1m";
                        };
                    })
                    (mkIf cfg.admin.restrict {
                        vaultwarden-admin-allowlist.ipAllowList.sourceRange = cfg.admin.allowedRanges;
                    })
                    (mkIf cfg.mtls.enable {
                        vaultwarden-mtls-auth.basicAuth = {
                            usersFile = mtlsUsersFile;
                            realm = "Vaultwarden client certificate";
                        };
                        vaultwarden-mtls-path.replacePath.path = "/client.p12";
                        vaultwarden-mtls-download-headers.headers.customResponseHeaders = {
                            Content-Disposition = "attachment; filename=\"vaultwarden-client.p12\"";
                        };
                    })
                ];
            }
            (mkIf cfg.mtls.enable {
                tls.options.vaultwarden-mtls.clientAuth = {
                    caFiles = [ mtlsCa ];
                    clientAuthType = "RequireAndVerifyClientCert";
                };
            })
        ];

        # Cert generation must finish before Traefik loads the CA path.
        systemd.services.traefik = mkIf cfg.mtls.enable {
            after = [ "vaultwarden-mtls-certs.service" ];
            requires = [ "vaultwarden-mtls-certs.service" ];
        };

        homelab.borgbackup.jobs = mkIf (cfg.backup.enable && config.homelab.borgbackup.enable) {
            vaultwarden-borgbase = {
                paths = [ cfg.backup.dir ];
                repo = cfg.backup.repo;
                schedule = cfg.backup.schedule;
                encryption.mode = "repokey-blake2";
                prune.keep = filterAttrs (_: v: v != null) cfg.backup.prune.keep;
                preHook = "${pkgs.systemd}/bin/systemctl start backup-vaultwarden.service";
            };
        };

        homelab.traefik.routes = mkIf config.homelab.traefik.enable (
            [
                {
                    name = "vaultwarden";
                    subdomain = cfg.subdomain;
                    inherit backendUrl;
                    middlewares = vaultMiddlewares;
                    tlsOptions = if cfg.mtls.enable then "vaultwarden-mtls" else null;
                }
            ]
            ++ optional cfg.admin.restrict {
                name = "vaultwarden-admin";
                subdomain = cfg.subdomain;
                inherit backendUrl;
                pathPrefix = "/admin";
                priority = 100;
                middlewares = vaultMiddlewares ++ [ "vaultwarden-admin-allowlist" ];
                tlsOptions = if cfg.mtls.enable then "vaultwarden-mtls" else null;
            }
            ++ optional cfg.mtls.enable {
                # Break-glass on a separate Host: Traefik TLS options are per-hostname,
                # so path-based exceptions on `subdomain` would disable mTLS entirely.
                name = "vaultwarden-mtls-download";
                subdomain = mtlsDownloadSubdomain;
                backendUrl = "http://127.0.0.1:${toString cfg.mtls.listenPort}";
                middlewares = [
                    "default-headers"
                    "https-redirect"
                    "vaultwarden-mtls-auth"
                    "vaultwarden-mtls-path"
                    "vaultwarden-mtls-download-headers"
                ];
            }
        );

        homelab.fail2ban.jails = mkIf (cfg.fail2ban.enable && config.homelab.fail2ban.enable) (
            [
                {
                    name = "vaultwarden-login";
                    traefik = {
                        host = cfg.subdomain;
                        paths = [ "/identity/connect/token" ];
                        methods = [ "POST" ];
                        statusCodes = [ 400 401 ];
                    };
                    settings = {
                        maxretry = 5;
                        findtime = "10m";
                        bantime = "1h";
                    };
                }
                {
                    name = "vaultwarden-admin";
                    traefik = {
                        host = cfg.subdomain;
                        pathPrefixes = [ "/admin" ];
                        statusCodes = [ 401 403 ];
                    };
                    settings = {
                        maxretry = 3;
                        findtime = "10m";
                        bantime = "24h";
                    };
                }
            ]
            ++ optional cfg.mtls.enable {
                name = "vaultwarden-mtls-download";
                traefik = {
                    host = mtlsDownloadSubdomain;
                    statusCodes = [ 401 ];
                };
                settings = {
                    maxretry = 5;
                    findtime = "10m";
                    bantime = "1h";
                };
            }
        );
    };
}
