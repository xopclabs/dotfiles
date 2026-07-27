{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.autoUpdate;

    hostName = config.metadata.hostName;
    userHome = config.users.users.${cfg.user}.home;
    stateDir = "/var/lib/nixos-auto-update";

    publisherTokenSopsKey = config.homelab.ntfy.publishers.${cfg.ntfy.publisher}.tokenSopsKey;

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

        owner=$(stat -c '%u:%g' "$lock")
        cp -p "$lock" "$prev"
        before=$(sha256sum "$lock" | cut -d' ' -f1)

        # Update as the clone's owner so flake.lock stays user-writable and
        # `git checkout flake.lock` keeps working without sudo.
        if ! changes=$(runuser -u ${cfg.user} -- \
            env HOME=${userHome} nix flake update ${concatStringsSep " " cfg.inputs} 2>&1); then
            echo "$changes" >&2
            notify "${hostName}: flake update failed" high rotating_light "$changes"
            exit 1
        fi
        echo "$changes"

        if [ "$before" = "$(sha256sum "$lock" | cut -d' ' -f1)" ]; then
            echo "auto-update: inputs already current, nothing to do"
            exit 0
        fi

        if ! nixos-rebuild switch --flake "${cfg.flake}#${hostName}" 2>&1 \
            | tee "${stateDir}/last-rebuild.log"; then
            # Leave the machine on a lock that is known to build. The rejected
            # lock is kept outside the clone so git status stays meaningful.
            cp "$lock" "${stateDir}/flake.lock.failed"
            cp -p "$prev" "$lock"
            chown "$owner" "$lock"
            notify "${hostName}: auto-update rebuild FAILED" high rotating_light \
                "Reverted to the previous lock.
Rejected lock: ${stateDir}/flake.lock.failed
Log: ${stateDir}/last-rebuild.log"
            exit 1
        fi

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
            default = [ "nixpkgs" ];
            example = [ "nixpkgs" "home-manager" ];
            description = ''
                Flake inputs to update.
                Defaults to nixpkgs alone, which carries the security-relevant packages while leaving churn-prone inputs pinned.
                An empty list updates every input, matching bare `nix flake update`.
            '';
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
        ];

        systemd.services.nixos-auto-update = {
            description = "Update flake inputs and rebuild from the local clone";
            # Needs the network for both the input fetch and the binary cache.
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            serviceConfig = {
                Type = "oneshot";
                WorkingDirectory = cfg.flake;
                ExecStart = updateScript;
                Environment = [ "HOME=/root" ];
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
