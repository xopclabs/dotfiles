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
