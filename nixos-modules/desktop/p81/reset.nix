{ writeShellScriptBin
, coreutils
, iproute2
, procps
, systemd
, p81ctl
# Deliberately without defaults: `desktop.p81` is the single source of truth,
# and a fallback here would silently win arguments it never actually gets.
, autoConnect
, connectTimeoutSec
, resetAttempts
}:

writeShellScriptBin "p81-reset" ''
    set -euo pipefail
    IP=${iproute2}/bin/ip
    PKILL=${procps}/bin/pkill
    SLEEP=${coreutils}/bin/sleep
    SYSTEMCTL=${systemd}/bin/systemctl
    P81CTL=${p81ctl}/bin/p81ctl

    reset_agent() {
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
    }

    ${if autoConnect then ''
        attempt=1
        while :; do
            reset_agent

            echo "p81-reset: reconnecting the VPN (attempt $attempt/${toString resetAttempts})..."
            code=0
            "$P81CTL" connect --timeout ${toString connectTimeoutSec} || code=$?

            if [ "$code" -eq 0 ]; then
                echo 'p81-reset: done, the tunnel is up again.'
                exit 0
            fi

            # A logged out agent needs the browser flow, so no amount of
            # resetting will bring the tunnel back.
            if [ "$code" -eq 3 ]; then
                echo 'p81-reset: the agent is logged out. Open the Harmony SASE / Perimeter81 app and sign in.'
                exit 0
            fi

            if [ "$attempt" -ge ${toString resetAttempts} ]; then
                echo 'p81-reset: the tunnel is still down. Open the Harmony SASE / Perimeter81 app and connect manually.'
                exit 0
            fi

            attempt=$((attempt + 1))
            echo 'p81-reset: the tunnel did not come up, resetting the agent again...'
        done
    '' else ''
        reset_agent
        echo 'p81-reset: done. Open the Harmony SASE / Perimeter81 app and connect again if needed.'
    ''}
''
