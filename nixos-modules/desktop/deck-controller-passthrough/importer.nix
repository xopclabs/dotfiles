{ config, cfg, lib, pkgs, usbip }:

let
    icfg = cfg.importer;
    importerService = "deck-controller-passthrough-importer.service";
    gamescopeService = "deck-controller-passthrough-gamescope.service";
    attachedPorts = pkgs.writeShellScript "deck-controller-passthrough-attached-ports" ''
        set -eu
        ${usbip}/bin/usbip port | ${pkgs.gawk}/bin/awk \
            -v device=${lib.escapeShellArg "${cfg.device.vendorId}:${cfg.device.productId}"} \
            -v remote=${lib.escapeShellArg "usbip://${icfg.exporterAddress}:3240/"} '
            function emit() {
                if (port != "" && found_device && found_remote) print port
            }
            /^Port [0-9]+:/ {
                emit()
                port = $2
                sub(/:$/, "", port)
                found_device = 0
                found_remote = 0
                next
            }
            index($0, device) { found_device = 1 }
            index($0, remote) { found_remote = 1 }
            END { emit() }
        '
    '';
    start = pkgs.writeShellScript "deck-controller-passthrough-importer-start" ''
        set -eu

        if [ -n "$(${attachedPorts})" ]; then
            exit 0
        fi

        remote=${lib.escapeShellArg icfg.exporterAddress}
        bus_id="$(${usbip}/bin/usbip list --remote "$remote" | ${pkgs.gawk}/bin/awk '
            /^[[:space:]]*[0-9]+-[0-9.]+:.*\(${cfg.device.vendorId}:${cfg.device.productId}\)/ {
                bus = $1
                sub(/:$/, "", bus)
                print bus
                exit
            }
        ')"

        if [ -z "$bus_id" ]; then
            echo "Steam Deck controller ${cfg.device.vendorId}:${cfg.device.productId} is not exported by $remote" >&2
            exit 1
        fi

        ${usbip}/bin/usbip attach --remote "$remote" --busid "$bus_id"
    '';
    stop = pkgs.writeShellScript "deck-controller-passthrough-importer-stop" ''
        set -eu
        ${attachedPorts} | while read -r port; do
            ${usbip}/bin/usbip detach --port "$port" || true
        done
    '';
    knownHosts = pkgs.writeText "deck-controller-known-hosts" "deck-controller ${icfg.remoteControl.hostPublicKey}\n";
    ssh = lib.escapeShellArgs [
        "${pkgs.openssh}/bin/ssh"
        "-o" "BatchMode=yes"
        "-o" "ConnectTimeout=5"
        "-o" "IdentitiesOnly=yes"
        "-o" "StrictHostKeyChecking=yes"
        "-o" "UserKnownHostsFile=${knownHosts}"
        "-o" "GlobalKnownHostsFile=/dev/null"
        "-o" "HostKeyAlias=deck-controller"
        "-i" (toString icfg.remoteControl.identityFile)
    ];
    remote = lib.escapeShellArg "${icfg.remoteControl.user}@${icfg.exporterAddress}";
    gamescopeStart = pkgs.writeShellScript "deck-controller-passthrough-gamescope-start" ''
        set -eu
        remote_started=false
        cleanup() {
            ${pkgs.systemd}/bin/systemctl stop ${importerService} || true
            if [ "$remote_started" = true ]; then
                ${ssh} ${remote} stop || true
            fi
        }
        trap cleanup EXIT

        ${ssh} ${remote} start
        remote_started=true
        for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
            if ${pkgs.systemd}/bin/systemctl start ${importerService}; then
                trap - EXIT
                exit 0
            fi
            ${pkgs.coreutils}/bin/sleep 1
        done
        echo "Steam Deck controller export did not become available" >&2
        exit 1
    '';
    gamescopeStop = pkgs.writeShellScript "deck-controller-passthrough-gamescope-stop" ''
        set -eu
        ${pkgs.systemd}/bin/systemctl stop ${importerService} || true
        ${ssh} ${remote} stop || true
    '';
    reconnect = pkgs.writeShellScript "deck-controller-passthrough-reconnect" ''
        set -eu
        app_id="$(${pkgs.procps}/bin/ps -ww -eo args= | ${pkgs.gawk}/bin/awk '
            match($0, /SteamLaunch AppId=([0-9]+)/, fields) {
                print fields[1]
                exit
            }
        ')"

        ${pkgs.systemd}/bin/systemctl restart ${gamescopeService}

        if [ -n "$app_id" ]; then
            user=${lib.escapeShellArg config.metadata.user}
            uid="$(${pkgs.coreutils}/bin/id -u "$user")"
            ${pkgs.util-linux}/bin/runuser -u "$user" -- \
                ${pkgs.coreutils}/bin/env XDG_RUNTIME_DIR="/run/user/$uid" DISPLAY=:0 \
                ${pkgs.systemd}/bin/systemd-run --user --collect --quiet \
                ${config.programs.steam.package}/bin/steam "steam://forceinputappid/$app_id"
        fi
    '';
    reconnectCommand = pkgs.writeShellScript "deck-controller-passthrough-reconnect-command" ''
        set -eu
        if [ "''${SSH_ORIGINAL_COMMAND:-}" != reconnect ]; then
            echo "only reconnect is permitted" >&2
            exit 2
        fi
        exec /run/wrappers/bin/sudo ${reconnect}
    '';
in
lib.mkMerge [
    {
        systemd.services.deck-controller-passthrough-importer = {
            description = "Import the Steam Deck controller over USB/IP";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = start;
                ExecStop = stop;
            };
        };
    }

    (lib.mkIf icfg.reconnectControl.enable (lib.mkMerge [
        {
            networking.firewall = {
                extraCommands = lib.mkIf (!config.networking.nftables.enable) ''
                    ${config.networking.firewall.package}/bin/iptables -A nixos-fw -p tcp -s ${icfg.exporterAddress} --dport 22 -j nixos-fw-accept
                '';
                extraInputRules = lib.mkIf config.networking.nftables.enable ''
                    ip saddr ${icfg.exporterAddress} tcp dport 22 accept
                '';
            };

            services.openssh.enable = true;

            users.users.${icfg.reconnectControl.user} = {
                isSystemUser = true;
                group = icfg.reconnectControl.user;
                shell = pkgs.bashInteractive;
                openssh.authorizedKeys.keys = [
                    "from=\"${icfg.exporterAddress}\",command=\"${reconnectCommand}\",no-agent-forwarding,no-port-forwarding,no-pty,no-user-rc,no-X11-forwarding ${icfg.reconnectControl.authorizedKey}"
                ];
            };
            users.groups.${icfg.reconnectControl.user} = {};

            security.sudo.extraRules = [{
                users = [ icfg.reconnectControl.user ];
                commands = [{
                    command = toString reconnect;
                    options = [ "NOPASSWD" ];
                }];
            }];
        }
    ]))

    (lib.mkIf icfg.gamescopeLifecycle.enable {
        systemd.services.deck-controller-passthrough-gamescope = {
            description = "Enable Steam Deck controller forwarding for Gamescope";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = gamescopeStart;
                ExecStop = gamescopeStop;
                Restart = "on-failure";
                RestartSec = 5;
            };
        };

        systemd.user.services.gamescope-session.serviceConfig = {
            ExecStartPre = lib.mkBefore [
                "${pkgs.systemd}/bin/systemctl --no-ask-password --no-block start ${gamescopeService}"
            ];
            ExecStopPost = lib.mkAfter [
                "${pkgs.systemd}/bin/systemctl --no-ask-password --no-block stop ${gamescopeService}"
            ];
        };

        security.polkit.extraConfig = ''
            polkit.addRule(function(action, subject) {
              if (
                action.id == "org.freedesktop.systemd1.manage-units" &&
                action.lookup("unit") == "${gamescopeService}" &&
                subject.user == "${config.metadata.user}" &&
                subject.local
              ) {
                return polkit.Result.YES;
              }
            });
        '';
    })
]
