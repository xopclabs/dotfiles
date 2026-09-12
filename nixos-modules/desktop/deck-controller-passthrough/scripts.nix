{ cfg, pkgs, usbip }:
let
    findDevice = pkgs.writeShellScript "deck-controller-passthrough-find-device" ''
        set -eu

        for device in /sys/bus/usb/devices/*; do
            [ -r "$device/idVendor" ] && [ -r "$device/idProduct" ] || continue
            read -r vendor < "$device/idVendor"
            read -r product < "$device/idProduct"
            if [ "$vendor" = ${pkgs.lib.escapeShellArg cfg.vendorId} ] && [ "$product" = ${pkgs.lib.escapeShellArg cfg.productId} ]; then
                basename "$device"
                exit 0
            fi
        done

        echo "Steam Deck controller ${cfg.vendorId}:${cfg.productId} was not found" >&2
        exit 1
    '';

    watchdogPeer = if cfg.allowedPeerAddress != null then cfg.allowedPeerAddress else "127.0.0.1";
    remoteIdentityFile = if cfg.remoteControl.identityFile != null then cfg.remoteControl.identityFile else "/dev/null";
    remoteHostPublicKey = if cfg.remoteControl.hostPublicKey != null then cfg.remoteControl.hostPublicKey else "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    remoteKnownHosts = pkgs.writeText "deck-controller-known-hosts" "deck-controller ${remoteHostPublicKey}\n";
    ssh = "${pkgs.openssh}/bin/ssh -o BatchMode=yes -o ConnectTimeout=5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${remoteKnownHosts} -o GlobalKnownHostsFile=/dev/null -o HostKeyAlias=deck-controller -o HostKeyAlgorithms=ssh-ed25519 -o PubkeyAcceptedAlgorithms=ssh-ed25519 -i ${remoteIdentityFile}";
    remoteControlScript = pkgs.writeShellScript "deck-controller-passthrough-remote-control" ''
        set -eu
        case "''${1:-}" in
            start|stop)
                exec ${pkgs.systemd}/bin/systemctl "$1" deck-controller-passthrough-exporter.service
                ;;
            *)
                echo "usage: deck-controller-passthrough-remote-control {start|stop}" >&2
                exit 2
                ;;
        esac
    '';
in {
    exporterStart = pkgs.writeShellScript "deck-controller-passthrough-exporter-start" ''
        set -eu
        bus_id="$(${findDevice})"
        if ! ${usbip}/bin/usbip bind --busid "$bus_id"; then
            ${usbip}/bin/usbip unbind --busid "$bus_id" || true
            ${pkgs.systemd}/bin/udevadm trigger --action=change --subsystem-match=usb
            exit 1
        fi
    '';

    exporterStop = pkgs.writeShellScript "deck-controller-passthrough-exporter-stop" ''
        set -eu
        bus_id="$(${findDevice})" || exit 0
        ${usbip}/bin/usbip unbind --busid "$bus_id" || true
        ${pkgs.systemd}/bin/udevadm trigger --action=change --subsystem-match=usb
    '';

    watchdog = pkgs.writeShellScript "deck-controller-passthrough-watchdog" ''
        set -eu
        seen_connection=false
        absent_since=0

        while true; do
            if ${pkgs.iproute2}/bin/ss -Htn state established '( sport = :3240 )' | ${pkgs.gawk}/bin/awk -v peer=${pkgs.lib.escapeShellArg watchdogPeer} '$6 ~ ("^" peer ":[0-9]+$") { found = 1 } END { exit !found }'; then
                seen_connection=true
                absent_since=0
            elif "$seen_connection"; then
                now="$(${pkgs.coreutils}/bin/date +%s)"
                if [ "$absent_since" -eq 0 ]; then
                    absent_since="$now"
                elif [ $((now - absent_since)) -ge ${toString cfg.disconnectGraceSeconds} ]; then
                    ${pkgs.systemd}/bin/systemctl --no-block stop deck-controller-passthrough-exporter.service
                    exit 0
                fi
            fi
            ${pkgs.coreutils}/bin/sleep 5
        done
    '';

    remoteControl = remoteControlScript;

    remoteCommand = pkgs.writeShellScript "deck-controller-passthrough-remote-command" ''
        set -eu
        case "''${SSH_ORIGINAL_COMMAND:-}" in
            start|stop)
                exec /run/wrappers/bin/sudo ${remoteControlScript} "$SSH_ORIGINAL_COMMAND"
                ;;
            *)
                echo "only start or stop is permitted" >&2
                exit 2
                ;;
        esac
    '';

    importerStart = pkgs.writeShellScript "deck-controller-passthrough-importer-start" ''
        set -eu

        remote=${pkgs.lib.escapeShellArg cfg.exporterAddress}
        exported="$(${usbip}/bin/usbip list --remote "$remote")"
        bus_id="$(printf '%s\n' "$exported" | ${pkgs.gawk}/bin/awk '
            /^[[:space:]]*[0-9]+-[0-9.]+:.*\(${cfg.vendorId}:${cfg.productId}\)/ {
                bus = $1
                sub(/:$/, "", bus)
                print bus
                exit
            }
        ')"

        if [ -z "$bus_id" ]; then
            echo "Steam Deck controller ${cfg.vendorId}:${cfg.productId} is not exported by $remote" >&2
            exit 1
        fi

        if ${usbip}/bin/usbip port | ${pkgs.gnugrep}/bin/grep -Fq "usbip://$remote:3240/$bus_id"; then
            exit 0
        fi

        ${usbip}/bin/usbip attach --remote "$remote" --busid "$bus_id"
    '';

    importerStop = pkgs.writeShellScript "deck-controller-passthrough-importer-stop" ''
        set -eu
        ${usbip}/bin/usbip port | ${pkgs.gawk}/bin/awk '
            /^Port [0-9]+:/ {
                port = $2
                sub(/:$/, "", port)
            }
            index($0, "usbip://${cfg.exporterAddress}:3240/") && port != "" {
                print port
            }
        ' | while read -r port; do
            ${usbip}/bin/usbip detach --port "$port" || true
        done
    '';

    gamescopeStart = pkgs.writeShellScript "deck-controller-passthrough-gamescope-start" ''
        set -eu
        cleanup() {
            ${pkgs.systemd}/bin/systemctl stop deck-controller-passthrough-importer.service || true
            ${ssh} ${cfg.remoteControl.user}@${cfg.exporterAddress} stop || true
        }
        trap cleanup EXIT

        ${ssh} ${cfg.remoteControl.user}@${cfg.exporterAddress} start
        for attempt in $(${pkgs.coreutils}/bin/seq 1 30); do
            if ${pkgs.systemd}/bin/systemctl start deck-controller-passthrough-importer.service; then
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
        ${pkgs.systemd}/bin/systemctl stop deck-controller-passthrough-importer.service || true
        ${ssh} ${cfg.remoteControl.user}@${cfg.exporterAddress} stop || true
    '';

    command = pkgs.writeShellScriptBin "deck-controller-passthrough" ''
        set -eu
        case "''${1:-}" in
            start|stop|restart|status)
                exec ${pkgs.systemd}/bin/systemctl "$1" deck-controller-passthrough-${cfg.role}.service
                ;;
            *)
                echo "usage: deck-controller-passthrough {start|stop|restart|status}" >&2
                exit 2
                ;;
        esac
    '';
}
