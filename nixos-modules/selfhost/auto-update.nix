{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.autoUpdate;

    hostName = config.metadata.hostName;
    userHome = config.users.users.${cfg.user}.home;
    stateDir = "/var/lib/nixos-auto-update";

    publisherTokenSopsKey = config.homelab.ntfy.publishers.${cfg.ntfy.publisher}.tokenSopsKey;

    # libgit2 refuses to open a repository owned by another user, which the root
    # rebuild always is. Scoping the exemption to this unit's HOME keeps it out of
    # the system and interactive-root git config.
    gitConfigFile = pkgs.writeText "nixos-auto-update-gitconfig" ''
        [safe]
            directory = ${cfg.flake}
            directory = ${cfg.flake}/.git
    '';

    # A no-op stub keeps the update script free of conditionals when ntfy is off.
    notifyFn =
        if cfg.ntfy.enable
        then ''
            notify() {
                ${pkgs.curl}/bin/curl -fsS \
                    -H "Authorization: Bearer $(cat ${config.sops.secrets."${publisherTokenSopsKey}".path})" \
                    -H "Title: $1" \
                    -H "Priority: $2" \
                    -H "Tags: $3" \
                    --data-binary "$4" \
                    "${cfg.ntfy.url}/${cfg.ntfy.topic}" > /dev/null \
                    || echo "auto-update: ntfy publish failed" >&2
            }
        ''
        else ''
            notify() { :; }
        '';

    updateScript = pkgs.writeShellScript "nixos-auto-update" ''
        set -euo pipefail

        export PATH="${makeBinPath [
            pkgs.coreutils
            pkgs.git
            pkgs.util-linux
            config.nix.package
            pkgs.nixos-rebuild
        ]}:$PATH"

        ${notifyFn}

        lock="${cfg.flake}/flake.lock"
        prev="${stateDir}/flake.lock.prev"
        log="${stateDir}/last-rebuild.log"

        owner=$(stat -c '%u:%g' "$lock")
        cp -p "$lock" "$prev"
        before=$(sha256sum "$lock" | cut -d' ' -f1)

        # Track whether the lock was mutated and whether we already notified.
        # An EXIT trap covers OOM / SIGTERM, which otherwise leave a dirty lock
        # and skip the failure notification.
        updated=0
        finished=0
        changes=""

        revert_lock() {
            if [ "$updated" != 1 ]; then
                return 0
            fi
            if [ "$(sha256sum "$lock" | cut -d' ' -f1)" = "$(sha256sum "$prev" | cut -d' ' -f1)" ]; then
                return 0
            fi
            cp "$lock" "${stateDir}/flake.lock.failed" 2>/dev/null || true
            cp -p "$prev" "$lock"
            chown "$owner" "$lock" || true
        }

        fail_notify() {
            if [ "$finished" = 1 ]; then
                return 0
            fi
            finished=1
            revert_lock
            log_tail=""
            if [ -f "$log" ]; then
                log_tail=$(tail -n 40 "$log" | head -c 3500)
            fi
            notify "${hostName}: auto-update rebuild FAILED" high rotating_light \
                "''${changes:-lock was updated}

Reverted to the previous lock.

--- last rebuild output ---
$log_tail"
        }

        trap fail_notify EXIT

        # Update as the clone's owner so flake.lock stays user-writable and
        # `git checkout flake.lock` keeps working without sudo.
        if ! changes=$(runuser -u ${cfg.user} -- \
            env HOME=${userHome} nix flake update ${concatStringsSep " " cfg.inputs} 2>&1); then
            echo "$changes" >&2
            finished=1
            notify "${hostName}: flake update failed" high rotating_light "$changes"
            exit 1
        fi
        echo "$changes"

        if [ "$before" = "$(sha256sum "$lock" | cut -d' ' -f1)" ]; then
            echo "auto-update: inputs already current, nothing to do"
            finished=1
            exit 0
        fi
        updated=1

        # Serialise the rebuild. Parallel eval/build is what pushes peak RSS
        # past a small VPS's RAM+swap budget.
        if ! nixos-rebuild switch \
            --flake "${cfg.flake}#${hostName}" \
            --max-jobs ${toString cfg.maxJobs} \
            --cores ${toString cfg.cores} \
            2>&1 | tee "$log"; then
            fail_notify
            exit 1
        fi

        finished=1
        notify "${hostName}: auto-update applied" default package \
            "$changes

flake.lock is now dirty. Verify, then commit it to bless this state."
    '';
in
{
    options.homelab.autoUpdate = {
        enable = mkEnableOption "unattended nixpkgs updates rebuilt from a local clone";

        flake = mkOption {
            type = types.str;
            default = "/home/${config.metadata.user}/dotfiles";
            description = ''
                Path to the local clone to update and rebuild from.
                Nothing is ever pulled or committed, so the working tree stays under your control.
                A dirty flake.lock is therefore the marker for "running, but not yet blessed".
            '';
        };

        user = mkOption {
            type = types.str;
            default = config.metadata.user;
            description = "Owner of the clone, used to run `nix flake update` so the lock file does not become root-owned.";
        };

        inputs = mkOption {
            type = types.listOf types.str;
            # home-manager and nixvim track nixpkgs closely enough that bumping
            # nixpkgs alone routinely breaks eval (infinite recursion in nixvim).
            default = [ "nixpkgs" "home-manager" "nixvim" ];
            example = [ "nixpkgs" "home-manager" "nixvim" ];
            description = ''
                Flake inputs to update.
                Defaults to nixpkgs plus the tightly-coupled home-manager and nixvim inputs.
                An empty list updates every input, matching bare `nix flake update`.
            '';
        };

        maxJobs = mkOption {
            type = types.ints.positive;
            default = 1;
            description = ''
                `--max-jobs` passed to nixos-rebuild.
                Keep at 1 on small VPS hosts; parallel jobs are the main driver of peak RSS.
            '';
        };

        cores = mkOption {
            type = types.ints.positive;
            default = 1;
            description = "`--cores` passed to nixos-rebuild (per-job parallelism).";
        };

        schedule = mkOption {
            type = types.str;
            default = "daily";
            description = "Systemd calendar expression for the update timer.";
        };

        randomizedDelaySec = mkOption {
            type = types.str;
            default = "45min";
            description = "Random delay added to the trigger time, so the rebuild does not start on the hour every day.";
        };

        ntfy = {
            enable = mkEnableOption "ntfy notifications for update results";

            url = mkOption {
                type = types.str;
                default = "http://127.0.0.1:${toString config.homelab.ntfy.port}";
                description = ''
                    Base URL of the ntfy server to publish to.
                    Defaults to a local ntfy over loopback, which avoids depending on DNS, TLS or the reverse proxy.
                '';
            };

            topic = mkOption {
                type = types.str;
                default = "system";
                description = "ntfy topic to publish update results to.";
            };

            publisher = mkOption {
                type = types.str;
                default = "auto-update";
                description = ''
                    Name of the `homelab.ntfy.publishers` entry to authenticate as.
                    The entry is declared automatically, so only its token has to be added to sops.
                '';
            };
        };
    };

    config = mkIf cfg.enable {
        assertions = [
            {
                assertion = cfg.ntfy.enable -> config.homelab.ntfy.enable;
                message = ''
                    homelab.autoUpdate.ntfy.enable requires homelab.ntfy on the same host, which owns the publisher token secret.
                '';
            }
        ];

        # ntfy declares the token secret and provisions the account from this.
        homelab.ntfy.publishers = mkIf cfg.ntfy.enable {
            ${cfg.ntfy.publisher}.topics = [ cfg.ntfy.topic ];
        };

        systemd.tmpfiles.rules = [
            "d ${stateDir} 0700 root root -"
            "L+ ${stateDir}/.gitconfig - - - - ${gitConfigFile}"
        ];

        systemd.services.nixos-auto-update = {
            description = "Update flake inputs and rebuild from the local clone";
            # Needs the network for both the input fetch and the binary cache.
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            serviceConfig = {
                Type = "oneshot";
                # Eval of a full NixOS+HM+nixvim system routinely needs multi-GB
                # for tens of minutes; never let systemd time it out mid-build.
                TimeoutStartSec = "3h";
                WorkingDirectory = cfg.flake;
                ExecStart = updateScript;
                # HOME must be writable for Nix's cache and is where libgit2 looks
                # for the safe.directory exemption above.
                Environment = [ "HOME=${stateDir}" ];
                # Prefer reclaiming from this unit under memory pressure, but do
                # not set MemoryMax — that would just OOM-kill us earlier.
                OOMScoreAdjust = 200;
            };
        };

        systemd.timers.nixos-auto-update = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
                OnCalendar = cfg.schedule;
                RandomizedDelaySec = cfg.randomizedDelaySec;
                Persistent = true;
            };
        };
    };
}
