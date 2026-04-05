{ config, lib, pkgs, inputs, ... }:

with lib;
let
    cfg = config.homelab.arr-stack.lrcget;
    arrCfg = config.homelab.arr-stack;
    arrProxyEnvFile = "/run/arr-proxy.env";

    lrcgetPkg = inputs.lrcget-cli.packages.${pkgs.system}.default;

    runScript = pkgs.writeShellApplication {
        name = "lrcget-watch-run";
        runtimeInputs = [ lrcgetPkg ];
        text = ''
            set -euo pipefail
            export HOME="${cfg.dataDir}"
            export XDG_CONFIG_HOME="''${HOME}/.config"
            export XDG_DATA_HOME="''${HOME}/.local/share"
            mkdir -p "''${XDG_CONFIG_HOME}/lrcget-cli" "''${XDG_DATA_HOME}/lrcget-cli"

            export LRCGET_DATABASE_PATH="${cfg.dataDir}/lrcget.db"
            ${concatStringsSep "\n            " (
                mapAttrsToList (n: v: "export ${n}=\"${toString v}\"") cfg.environment
            )}
            export LRCGET_TRY_EMBED_LYRICS=${boolToString cfg.tryEmbedLyrics}

            INIT_STAMP="${cfg.dataDir}/.lrcget-init-done"
            if [ ! -f "$INIT_STAMP" ]; then
                lrcget init "${cfg.musicDir}"
                touch "$INIT_STAMP"
            fi

            exec lrcget watch "${cfg.musicDir}" \
                --initial-scan \
                --debounce-seconds ${toString cfg.debounceSeconds} \
                --batch-size ${toString cfg.batchSize}
        '';
    };
in
{
    options.homelab.arr-stack.lrcget = {
        enable = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Enable [lrcget-cli](https://github.com/musicdock/lrcget-cli): watch the music library and fetch
              synced/plain lyrics via LRCLIB (built from flake input `lrcget-cli`).
            '';
        };

        musicDir = mkOption {
            type = types.path;
            default = config.metadata.selfhost.storage.media.musicDir;
            description = "Music library root (same path used for `lrcget init` and `lrcget watch`).";
        };

        dataDir = mkOption {
            type = types.path;
            default = "/var/lib/lrcget-cli";
            description = "State directory (database, XDG config, init stamp).";
        };

        proxy = mkOption {
            type = types.bool;
            default = true;
            description = "Use the same HTTP(S)_PROXY as other *arr services (arr-proxy-env).";
        };

        debounceSeconds = mkOption {
            type = types.int;
            default = 10;
            description = "Watch mode debounce before processing detected files.";
        };

        batchSize = mkOption {
            type = types.int;
            default = 50;
            description = "Maximum files to process in one watch batch.";
        };

        tryEmbedLyrics = mkEnableOption ''
          embedding lyrics into audio tags (sets `LRCGET_TRY_EMBED_LYRICS`; useful for Jellyfin and similar)
        '';

        environment = mkOption {
            type = types.attrsOf types.str;
            default = { };
            example = {
                RUST_LOG = "info";
                LRCGET_SKIP_TRACKS_WITH_SYNCED_LYRICS = "false";
            };
            description = ''
              Extra environment variables for lrcget (see upstream README), e.g. `RUST_LOG`.
              `LRCGET_TRY_EMBED_LYRICS` is set from `tryEmbedLyrics` and is exported after these entries,
              so it overrides a duplicate key here.
            '';
        };
    };

    config = mkIf (arrCfg.enable && cfg.enable) {
        systemd.tmpfiles.rules = [
            "d ${cfg.dataDir} 0750 ${config.metadata.user} users -"
        ];

        systemd.services.lrcget-watch = {
            description = "lrcget-cli: watch music library and download lyrics";
            after = [ "network-online.target" ] ++ optionals cfg.proxy [ "arr-proxy-env.service" ];
            wants = [ "network-online.target" ];
            requires = optionals cfg.proxy [ "arr-proxy-env.service" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
                Type = "simple";
                User = config.metadata.user;
                Group = "users";
                ExecStart = "${runScript}/bin/lrcget-watch-run";
                Restart = "on-failure";
                RestartSec = "30";
                # Lyrics are written next to audio files; state lives under dataDir.
                ReadWritePaths = [ cfg.musicDir cfg.dataDir ];
                RequiresMountsFor = [ cfg.musicDir cfg.dataDir ];
            } // optionalAttrs cfg.proxy {
                EnvironmentFile = arrProxyEnvFile;
            };
        };
    };
}
