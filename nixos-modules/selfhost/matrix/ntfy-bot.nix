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
        nativeCheckInputs = with pkgs.python3Packages; [
            matrix-nio
            aiohttp
            pyyaml
        ] ++ matrix-nio.optional-dependencies.e2e;
        checkPhase = ''
            runHook preCheck
            python -m unittest discover -s . -v
            runHook postCheck
        '';
    };
in
{
    options.homelab.matrix.ntfyBot = {
        enable = mkEnableOption ''
            Matrix reminder bot that pushes room activity to public ntfy topics.

            Configure via the matrix/ntfy-bot object in sops (secrets/shared/selfhost.yaml).
        '';

        sopsKey = mkOption {
            type = types.str;
            default = "matrix/ntfy-bot";
            description = ''
                Sops object prefix. Uses matrix/ntfy-bot/config and matrix/ntfy-bot/token from
                secrets/shared/selfhost.yaml.
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

        skipIfVpnConnected = mkOption {
            type = types.bool;
            default = true;
            description = ''
                Skip ntfy when the recipient currently has a live WireGuard handshake.

                The Matrix localpart is matched to `homelab.wireguard.peers.<name>`
                (e.g. `@pavel:...` → `pavel`, not `pavel-pc`). Override per subscriber
                with `wg_peers` in the sops bot config.
            '';
        };

        wgInterface = mkOption {
            type = types.str;
            default = "wg0";
            description = "WireGuard interface whose latest handshakes are checked";
        };

        wgHandshakeTimeout = mkOption {
            type = types.int;
            default = 180;
            description = ''
                Seconds since the latest handshake to treat a peer as connected.
                WireGuard expires sessions after 180s without a handshake.
            '';
        };
    };

    config = mkIf (matrixCfg.enable && cfg.enable) (let
        mb = cfg.sopsKey;
        checkVpn =
            cfg.skipIfVpnConnected && config.homelab.wireguard.enable;
        wgPeerKeysFile = pkgs.writeText "wg-peer-keys.json" (builtins.toJSON (
            mapAttrs (_: peer: peer.publicKey) config.homelab.wireguard.peers
        ));
    in {
        nixpkgs.config.permittedInsecurePackages = [
            "olm-3.2.16"
        ];

        sops.secrets.domain = {
            sopsFile = ../../../secrets/shared/selfhost.yaml;
        };

        sops.secrets."${mb}/config" = {
            sopsFile = ../../../secrets/shared/selfhost.yaml;
            owner = "matrix-ntfy-bot";
            group = "matrix-ntfy-bot";
            mode = "0400";
        };

        sops.secrets."${mb}/token" = {
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
                NTFY_TOKEN=$(${pkgs.coreutils}/bin/tr -d '[:space:]' < ${config.sops.secrets."${mb}/token".path})
                ${pkgs.coreutils}/bin/cat > ${runtimeEnv} <<EOF
                NTFY_URL=https://${cfg.ntfySubdomain}.$DOMAIN
                NTFY_TOKEN=$NTFY_TOKEN
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
                        ${config.sops.secrets."${mb}/config".path} \
                        --ntfy-url "$NTFY_URL" \
                        --ntfy-token "$NTFY_TOKEN" \
                        --homeserver "http://127.0.0.1:${toString matrixCfg.synapsePort}" \
                        --store-path "${cfg.dataDir}" \
                        --icon-url "${cfg.iconUrl}" \
                        --typing-grace-seconds ${toString cfg.typingGraceSeconds} \
                        ${optionalString checkVpn "--wg-bin ${pkgs.wireguard-tools}/bin/wg"} \
                        ${optionalString checkVpn "--wg-interface ${cfg.wgInterface}"} \
                        ${optionalString checkVpn "--wg-peer-keys ${wgPeerKeysFile}"} \
                        ${optionalString checkVpn "--wg-handshake-timeout ${toString cfg.wgHandshakeTimeout}"}
                '';
            } // optionalAttrs checkVpn {
                # CAP_NET_ADMIN is required to read `wg show` handshakes.
                AmbientCapabilities = [ "CAP_NET_ADMIN" ];
                CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
            };
        };
    });
}
