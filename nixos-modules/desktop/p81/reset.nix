{ writeShellScriptBin, coreutils, iproute2, procps, systemd }:

writeShellScriptBin "p81-reset" ''
    set -euo pipefail
    IP=${iproute2}/bin/ip
    PKILL=${procps}/bin/pkill
    SLEEP=${coreutils}/bin/sleep
    SYSTEMCTL=${systemd}/bin/systemctl

    echo 'p81-reset: stopping perimeter81-helper-daemon...'
    "$SYSTEMCTL" stop perimeter81-helper-daemon || true
    "$SLEEP" 2

    echo 'p81-reset: killing stray Perimeter81 child processes (if any)...'
    # Bubblewrap children may survive briefly; match paths seen in ps/cmdline
    for sig in TERM KILL; do
        "$PKILL" -"$sig" -f '/opt/Perimeter81/binaries/openvpn' 2>/dev/null || true
        "$PKILL" -"$sig" -f 'Perimeter81.*openvpn' 2>/dev/null || true
        "$PKILL" -"$sig" -f 'p81daemonhelper' 2>/dev/null || true
        "$SLEEP" 0.3
    done

    echo 'p81-reset: flushing routes and removing tun0 (if present)...'
    if "$IP" link show tun0 &>/dev/null; then
        while "$IP" route show dev tun0 2>/dev/null | grep -q .; do
            "$IP" route flush dev tun0 || break
        done
        "$IP" link set tun0 down 2>/dev/null || true
        "$IP" link delete tun0 2>/dev/null || true
    fi

    echo 'p81-reset: removing stale IPC sockets and leftover temp files...'
    # The daemon creates /tmp/app.p81helper (and, on some versions, the native
    # helper sockets below) on startup; after a hard kill these are not
    # unlinked. Leaving them can cause the GUI to stay connected to a dead
    # socket and report a phantom "connected" state while the new daemon
    # listens on a different descriptor.
    rm -f /tmp/app.p81helper \
        /run/p81-native-helper-parent.socket \
        /run/p81-native-helper-child.socket \
        /var/run/p81-native-helper-parent.socket \
        /var/run/p81-native-helper-child.socket

    # Atomic-write temporaries (config.json.<pid>) that survive a SIGKILL can
    # confuse the daemon's state machine on the next start.
    rm -f /var/lib/p81/etc/xopc/config.json.[0-9]* 2>/dev/null || true

    echo 'p81-reset: starting perimeter81-helper-daemon...'
    "$SYSTEMCTL" start perimeter81-helper-daemon

    echo 'p81-reset: done. Open the Harmony SASE / Perimeter81 app and connect again if needed.'
''
