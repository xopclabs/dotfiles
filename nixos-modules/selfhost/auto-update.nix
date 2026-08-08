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

    binPath = makeBinPath [
        pkgs.coreutils
        pkgs.git
        pkgs.util-linux
        pkgs.systemd
        pkgs.curl
        pkgs.jq
        config.nix.package
        pkgs.nixos-rebuild
    ];

    # A no-op stub keeps the update script free of conditionals when ntfy is off.
    notifyFn =
        if cfg.ntfy.enable
        then ''
            notify() {
                # Prefer loopback; if ntfy was briefly stopped during switch, retry
                # a few times while it comes back.
                local i=0
                while [ "$i" -lt 12 ]; do
                    if ${pkgs.curl}/bin/curl -fsS \
                        -H "Authorization: Bearer $(cat ${config.sops.secrets."${publisherTokenSopsKey}".path})" \
                        -H "Title: $1" \
                        -H "Priority: $2" \
                        -H "Tags: $3" \
                        --data-binary "$4" \
                        "${cfg.ntfy.url}/${cfg.ntfy.topic}" > /dev/null; then
                        return 0
                    fi
                    i=$((i + 1))
                    sleep 5
                done
                echo "auto-update: ntfy publish failed" >&2
            }
        ''
        else ''
            notify() { :; }
        '';

    nixpkgsRevFn = ''
        nixpkgs_rev_from() {
            local lock=$1 node rev
            node=$(${pkgs.jq}/bin/jq -r '.nodes.root.inputs.nixpkgs' "$lock")
            rev=$(${pkgs.jq}/bin/jq -r --arg n "$node" '.nodes[$n].locked.rev // empty' "$lock")
            printf '%s' "$rev" | ${pkgs.coreutils}/bin/head -c 12
        }
        nixpkgs_rev() {
            nixpkgs_rev_from "${cfg.flake}/flake.lock"
        }
    '';

    # Runs outside nixos-auto-update.service so `nixos-rebuild switch` can stop
    # that unit without killing the rebuild mid-activation.
    rebuildScript = pkgs.writeShellScript "nixos-auto-update-rebuild" ''
        set -euo pipefail
        export PATH="${binPath}:$PATH"
        export HOME="${stateDir}"

        ${notifyFn}
        ${nixpkgsRevFn}

        lock="${cfg.flake}/flake.lock"
        prev="${stateDir}/flake.lock.prev"
        log="${stateDir}/last-rebuild.log"
        owner=$(cat "${stateDir}/lock-owner")

        revert_lock() {
            if [ "$(sha256sum "$lock" | cut -d' ' -f1)" = "$(sha256sum "$prev" | cut -d' ' -f1)" ]; then
                return 0
            fi
            cp "$lock" "${stateDir}/flake.lock.failed" 2>/dev/null || true
            cp -p "$prev" "$lock"
            chown "$owner" "$lock" || true
        }

        if nixos-rebuild switch \
            --flake "${cfg.flake}#${hostName}" \
            --max-jobs ${toString cfg.maxJobs} \
            --cores ${toString cfg.cores} \
            2>&1 | tee "$log"; then
            before_rev=$(nixpkgs_rev_from "$prev")
            after_rev=$(nixpkgs_rev)
            if [ -z "$before_rev" ] && [ -z "$after_rev" ]; then
                msg="nixpkgs rev unknown"
            elif [ "$before_rev" = "$after_rev" ]; then
                msg="nixpkgs up to date (''${after_rev:-unknown})"
            else
                msg="nixpkgs ''${before_rev:-?} → ''${after_rev:-?}"
            fi
            notify "${hostName}: auto-update applied" default package "$msg"
            exit 0
        fi

        revert_lock
        log_tail=$(tail -n 30 "$log" | head -c 3500)
        notify "${hostName}: auto-update rebuild FAILED" high rotating_light "$log_tail"
        exit 1
    '';

    updateScript = pkgs.writeShellScript "nixos-auto-update" ''
        set -euo pipefail

        export PATH="${binPath}:$PATH"

        ${notifyFn}
        ${nixpkgsRevFn}

        lock="${cfg.flake}/flake.lock"
        prev="${stateDir}/flake.lock.prev"

        owner=$(stat -c '%u:%g' "$lock")
        cp -p "$lock" "$prev"
        before=$(sha256sum "$lock" | cut -d' ' -f1)

        # Update as the clone's owner so flake.lock stays user-writable and
        # `git checkout flake.lock` keeps working without sudo.
        if ! changes=$(runuser -u ${cfg.user} -- \
            env HOME=${userHome} nix flake update ${concatStringsSep " " cfg.inputs} 2>&1); then
            echo "$changes" >&2
            notify "${hostName}: flake update failed" high rotating_light \
                "$(printf '%s\n' "$changes" | tail -n 30 | head -c 3500)"
            exit 1
        fi
        echo "$changes"

        if [ "$before" = "$(sha256sum "$lock" | cut -d' ' -f1)" ]; then
            rev=$(nixpkgs_rev)
            notify "${hostName}: auto-update" default package \
                "nixpkgs up to date (''${rev:-unknown})"
            echo "auto-update: inputs already current, nothing to do"
            exit 0
        fi

        printf '%s' "$owner" > "${stateDir}/lock-owner"

        # Hand the switch off to a transient unit. `nixos-rebuild switch` stops
        # nixos-auto-update.service when that unit's definition changed (or is
        # restarted), which would SIGTERM a rebuild running inside this cgroup.
        if systemctl is-active --quiet nixos-auto-update-rebuild.service; then
            echo "auto-update: rebuild already running" >&2
            exit 1
        fi
        systemctl reset-failed nixos-auto-update-rebuild.service 2>/dev/null || true

        systemd-run \
            --collect \
            --unit=nixos-auto-update-rebuild \
            --property=Type=oneshot \
            --property=WorkingDirectory=${cfg.flake} \
            --property=Environment=HOME=${stateDir} \
            --property=TimeoutStartSec=3h \
            --property=OOMScoreAdjust=200 \
            ${rebuildScript}

        echo "auto-update: rebuild handed off to nixos-auto-update-rebuild.service"
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
            description = "Update flake inputs and hand off a system rebuild";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            serviceConfig = {
                Type = "oneshot";
                # Only the flake update runs here; the rebuild is a transient unit.
                TimeoutStartSec = "30min";
                WorkingDirectory = cfg.flake;
                ExecStart = updateScript;
                Environment = [ "HOME=${stateDir}" ];
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
