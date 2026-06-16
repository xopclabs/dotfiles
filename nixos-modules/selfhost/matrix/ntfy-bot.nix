{ config, lib, pkgs, ... }:

with lib;
let
    matrixCfg = config.homelab.matrix;
    cfg = matrixCfg.ntfyBot;
    runtimeEnv = "/run/matrix-ntfy-bot/env";

    matrixNtfyBot = pkgs.python3Packages.buildPythonApplication {
        pname = "matrix-ntfy-bot";
        version = "0.1.0";
        pyproject = true;
        src = ./.;
        nativeBuildInputs = with pkgs.python3Packages; [
            setuptools
        ];
        propagatedBuildInputs = with pkgs.python3Packages; [
            matrix-nio
            aiohttp
            pyyaml
        ] ++ matrix-nio.optional-dependencies.e2e;
        doCheck = true;
        checkInputs = with pkgs.python3Packages; [
            matrix-nio
            aiohttp
            pyyaml
        ] ++ matrix-nio.optional-dependencies.e2e;
    };
in
{
    options.homelab.matrix.ntfyBot = {
        enable = mkEnableOption ''
            Matrix reminder bot that pushes room activity to public ntfy topics.

            Requires a dedicated Matrix bot account, per-user ntfy topics on the VPS,
            and YAML config in sops (matrix/ntfy-bot-config). See module comments
            in hosts/homelab for onboarding steps.
        '';

        configSopsKey = mkOption {
            type = types.str;
            default = "matrix/ntfy-bot-config";
            description = ''
                Sops secret path containing the bot YAML config (access token, rooms,
                subscribers). Stored in secrets/shared/selfhost.yaml.
            '';
        };

        dataDir = mkOption {
            type = types.str;
            default = "/var/lib/matrix-ntfy-bot";
            description = "Persistent matrix-nio crypto/sync store";
        };

        ntfySubdomain = mkOption {
            type = types.str;
            default = "ntfy";
            description = ''
                Public ntfy subdomain on the VPS (e.g. "ntfy" for ntfy.$DOMAIN).
            '';
        };

        iconUrl = mkOption {
            type = types.str;
            default = "https://matrix.org/images/matrix-logo.png";
            description = "PNG/JPEG URL for ntfy notification icon";
        };

        typingGraceSeconds = mkOption {
            type = types.int;
            default = 30;
            description = ''
                Skip notifying a user if they were typing in the room within this
                many seconds before the message.
            '';
        };
    };

    config = mkIf (matrixCfg.enable && cfg.enable) {
        nixpkgs.config.permittedInsecurePackages = [
            "olm-3.2.16"
        ];

        sops.secrets.domain = {
            sopsFile = ../../../secrets/shared/selfhost.yaml;
        };

        sops.secrets.${cfg.configSopsKey} = {
            sopsFile = ../../../secrets/shared/selfhost.yaml;
            owner = "matrix-ntfy-bot";
            group = "matrix-ntfy-bot";
            mode = "0400";
        };

        users.users.matrix-ntfy-bot = {
            isSystemUser = true;
            group = "matrix-ntfy-bot";
            home = cfg.dataDir;
        };
        users.groups.matrix-ntfy-bot = {};

        systemd.services.matrix-ntfy-bot-env = {
            description = "Generate Matrix ntfy bot runtime environment";
            wantedBy = [ "multi-user.target" ];
            before = [ "matrix-ntfy-bot.service" ];
            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                RuntimeDirectory = "matrix-ntfy-bot";
            };
            script = ''
                DOMAIN=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.domain.path})
                ${pkgs.coreutils}/bin/cat > ${runtimeEnv} <<EOF
                NTFY_URL=https://${cfg.ntfySubdomain}.$DOMAIN
                EOF
                chown matrix-ntfy-bot:matrix-ntfy-bot ${runtimeEnv}
                chmod 400 ${runtimeEnv}
            '';
        };

        systemd.services.matrix-ntfy-bot = {
            description = "Matrix room reminder bot (ntfy push)";
            after = [
                "matrix-ntfy-bot-env.service"
                "matrix-synapse.service"
                "network-online.target"
            ];
            requires = [ "matrix-ntfy-bot-env.service" ];
            wants = [ "matrix-synapse.service" "network-online.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
                Type = "simple";
                User = "matrix-ntfy-bot";
                Group = "matrix-ntfy-bot";
                StateDirectory = "matrix-ntfy-bot";
                Restart = "on-failure";
                RestartSec = "10s";
                ExecStart = pkgs.writeShellScript "matrix-ntfy-bot-run" ''
                    set -euo pipefail
                    set -a
                    source ${runtimeEnv}
                    set +a
                    exec ${matrixNtfyBot}/bin/matrix-ntfy-bot \
                        ${config.sops.secrets.${cfg.configSopsKey}.path} \
                        --ntfy-url "$NTFY_URL" \
                        --homeserver "http://127.0.0.1:${toString matrixCfg.synapsePort}" \
                        --store-path "${cfg.dataDir}" \
                        --icon-url "${cfg.iconUrl}" \
                        --typing-grace-seconds ${toString cfg.typingGraceSeconds}
                '';
            };
        };
    };
}
