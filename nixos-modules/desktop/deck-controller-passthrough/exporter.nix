{ config, cfg, lib, pkgs, usbip }:

let
    ecfg = cfg.exporter;
    service = "deck-controller-passthrough-exporter.service";
    findDevice = pkgs.writeShellScript "deck-controller-passthrough-find-device" ''
        set -eu

        for device in /sys/bus/usb/devices/*; do
            [ -r "$device/idVendor" ] && [ -r "$device/idProduct" ] || continue
            read -r vendor < "$device/idVendor"
            read -r product < "$device/idProduct"
            if [ "$vendor" = ${lib.escapeShellArg cfg.device.vendorId} ] && [ "$product" = ${lib.escapeShellArg cfg.device.productId} ]; then
                basename "$device"
                exit 0
            fi
        done

        echo "Steam Deck controller ${cfg.device.vendorId}:${cfg.device.productId} was not found" >&2
        exit 1
    '';
    start = pkgs.writeShellScript "deck-controller-passthrough-exporter-start" ''
        set -eu
        bus_id="$(${findDevice})"
        if ! ${usbip}/bin/usbip bind --busid "$bus_id"; then
            ${usbip}/bin/usbip unbind --busid "$bus_id" || true
            ${pkgs.systemd}/bin/udevadm trigger --action=change --subsystem-match=usb
            exit 1
        fi
    '';
    stop = pkgs.writeShellScript "deck-controller-passthrough-exporter-stop" ''
        set -eu
        bus_id="$(${findDevice})" || exit 0
        ${usbip}/bin/usbip unbind --busid "$bus_id" || true
        ${pkgs.systemd}/bin/udevadm trigger --action=change --subsystem-match=usb
    '';
    sleepInhibitor = pkgs.writeShellScript "deck-controller-passthrough-sleep-inhibitor" ''
        exec ${pkgs.systemd}/bin/systemd-inhibit \
            --what=sleep \
            --mode=block \
            --who=deck-controller-passthrough \
            --why="Steam Deck controller is forwarded" \
            ${pkgs.coreutils}/bin/sleep infinity
    '';
    watchdog = pkgs.writeShellScript "deck-controller-passthrough-watchdog" ''
        set -eu
        absent_since="$(${pkgs.coreutils}/bin/date +%s)"

        while true; do
            if ${pkgs.iproute2}/bin/ss -Htn state established '( sport = :3240 )' | ${pkgs.gawk}/bin/awk -v peer=${lib.escapeShellArg ecfg.peerAddress} '
                {
                    remote = $4
                    sub(/:[0-9]+$/, "", remote)
                    if (remote == peer) found = 1
                }
                END { exit !found }
            '; then
                absent_since=0
            else
                now="$(${pkgs.coreutils}/bin/date +%s)"
                if [ "$absent_since" -eq 0 ]; then
                    absent_since="$now"
                elif [ $((now - absent_since)) -ge ${toString ecfg.disconnectGraceSeconds} ]; then
                    ${pkgs.systemd}/bin/systemctl --no-block stop ${service}
                    exit 0
                fi
            fi
            ${pkgs.coreutils}/bin/sleep 5
        done
    '';
    remoteControl = pkgs.writeShellScript "deck-controller-passthrough-remote-control" ''
        set -eu
        case "''${1:-}" in
            start|stop)
                exec ${pkgs.systemd}/bin/systemctl "$1" ${service}
                ;;
            *)
                echo "usage: deck-controller-passthrough-remote-control {start|stop}" >&2
                exit 2
                ;;
        esac
    '';
    remoteCommand = pkgs.writeShellScript "deck-controller-passthrough-remote-command" ''
        set -eu
        case "''${SSH_ORIGINAL_COMMAND:-}" in
            start|stop)
                exec /run/wrappers/bin/sudo ${remoteControl} "$SSH_ORIGINAL_COMMAND"
                ;;
            *)
                echo "only start or stop is permitted" >&2
                exit 2
                ;;
        esac
    '';
    reconnectKnownHosts = pkgs.writeText "deck-controller-importer-known-hosts"
        "deck-controller-importer ${ecfg.reconnectTrigger.hostPublicKey}\n";
    reconnect = pkgs.writeShellScriptBin "reconnect-deck-controller" ''
        set -eu
        if ${pkgs.openssh}/bin/ssh \
            -o BatchMode=yes \
            -o ConnectTimeout=5 \
            -o IdentitiesOnly=yes \
            -o StrictHostKeyChecking=yes \
            -o UserKnownHostsFile=${reconnectKnownHosts} \
            -o GlobalKnownHostsFile=/dev/null \
            -o HostKeyAlias=deck-controller-importer \
            -i ${ecfg.reconnectTrigger.identityFile} \
            ${ecfg.reconnectTrigger.user}@${ecfg.peerAddress} reconnect; then
            ${pkgs.libnotify}/bin/notify-send "Steam Deck controller" "Reconnection requested" || true
        else
            status=$?
            ${pkgs.libnotify}/bin/notify-send --urgency=critical "Steam Deck controller" "Reconnection failed" || true
            exit "$status"
        fi
    '';
    reconnectLauncher = pkgs.makeDesktopItem {
        name = "reconnect-deck-controller";
        desktopName = "Reconnect Deck Controller";
        comment = "Reconnect this Steam Deck's controller to the gaming PC";
        exec = "${reconnect}/bin/reconnect-deck-controller";
        icon = "input-gaming";
        terminal = false;
        categories = [ "Game" "Utility" ];
    };
    allowFromPeer = port: {
        networking.firewall = {
            extraCommands = lib.mkIf (!config.networking.nftables.enable) ''
                ${config.networking.firewall.package}/bin/iptables -A nixos-fw -p tcp -s ${ecfg.peerAddress} --dport ${toString port} -j nixos-fw-accept
            '';
            extraInputRules = lib.mkIf config.networking.nftables.enable ''
                ip saddr ${ecfg.peerAddress} tcp dport ${toString port} accept
            '';
        };
    };
in
lib.mkMerge [
    (allowFromPeer 3240)
    {
        systemd.services.deck-controller-passthrough-usbipd = {
            description = "USB/IP daemon for Steam Deck controller passthrough";
            serviceConfig = {
                ExecStart = "${usbip}/bin/usbipd";
                Restart = "on-failure";
            };
        };

        systemd.services.deck-controller-passthrough-exporter = {
            description = "Export the Steam Deck controller over USB/IP";
            requires = [ "deck-controller-passthrough-usbipd.service" ];
            after = [ "deck-controller-passthrough-usbipd.service" ];
            wantedBy = lib.optional ecfg.activateAtBoot "multi-user.target";
            partOf = [ "deck-controller-passthrough-usbipd.service" ];
            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = start;
                ExecStop = stop;
            };
        };

        systemd.services.deck-controller-passthrough-sleep-inhibitor = {
            description = "Inhibit sleep while the Steam Deck controller is forwarded";
            after = [ service ];
            wantedBy = [ service ];
            partOf = [ service ];
            serviceConfig = {
                ExecStart = sleepInhibitor;
            };
        };

        systemd.services.deck-controller-passthrough-watchdog = {
            description = "Restore Steam Deck local controls after USB/IP peer loss";
            after = [ service ];
            wantedBy = [ service ];
            partOf = [ service ];
            serviceConfig = {
                ExecStart = watchdog;
                Restart = "on-failure";
                RestartSec = 5;
                NoNewPrivileges = true;
                PrivateTmp = true;
                ProtectHome = true;
                ProtectSystem = "strict";
            };
        };
    }

    (lib.mkIf ecfg.reconnectTrigger.enable {
        environment.systemPackages = [ reconnect reconnectLauncher ];
    })

    (lib.mkIf ecfg.remoteControl.enable (lib.mkMerge [
        (allowFromPeer 22)
        {
            services.openssh.enable = true;

            users.users.${ecfg.remoteControl.user} = {
                isSystemUser = true;
                group = ecfg.remoteControl.user;
                shell = pkgs.bashInteractive;
                openssh.authorizedKeys.keys = [
                    "from=\"${ecfg.peerAddress}\",command=\"${remoteCommand}\",no-agent-forwarding,no-port-forwarding,no-pty,no-user-rc,no-X11-forwarding ${ecfg.remoteControl.authorizedKey}"
                ];
            };
            users.groups.${ecfg.remoteControl.user} = {};

            security.sudo.extraRules = [{
                users = [ ecfg.remoteControl.user ];
                commands = [{
                    command = toString remoteControl;
                    options = [ "NOPASSWD" ];
                }];
            }];
        }
    ]))
]
