# Never trace secret reads or PIN submission, even if invoked with bash -x.
set +x
umask 077
# Injected by the Nix wrapper; this path does not contain the PIN.
pin_file="${pin_file:-}"
monitor=false
scrcpy_args=()
for argument in "$@"; do
    if [[ "$argument" == --monitor ]]; then
        monitor=true
    else
        scrcpy_args+=("$argument")
    fi
done

fail() {
    printf '%s\n' "$1" >&2
    notify-send --app-name='Phone Control' --icon=smartphone --urgency=critical \
        'Phone Control' "$1" || true
    exit 1
}

runtime_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}/phone-control-$UID}"
mkdir -p "$runtime_dir"
exec 9>"$runtime_dir/phone-control.lock"
if ! flock -n 9; then
    # The first launch may still be connecting/unlocking. Give its window up to
    # ten seconds to appear, without starting another session or showing a popup.
    if [[ -n "${NIRI_SOCKET:-}" ]] && command -v niri >/dev/null 2>&1; then
        for ((attempt = 0; attempt < 40; attempt++)); do
            if window_id=$(niri msg --json windows 2>/dev/null | jq -er '
                [.[] | select(.app_id == "phone-control" and .title == "Phone Control")]
                | first | .id // empty
            ' 2>/dev/null); then
                if niri msg action focus-window --id "$window_id" >/dev/null 2>&1; then
                    if $monitor; then
                        printf '%s\n' 'Existing session focused. Close it and relaunch with --monitor to enable telemetry.'
                    fi
                    exit 0
                fi
            fi
            sleep 0.25
        done
    fi
    exit 0
fi

log=$(mktemp "$runtime_dir/phone-control.XXXXXX")
trap 'rm -f "$log"; unset pin' EXIT

# The persistent ADB server must not inherit the launcher session lock.
if ! adb start-server 9>&- >"$log" 2>&1; then
    fail 'Could not start ADB. Run phone-control in a terminal to diagnose it.'
fi
if ! adb mdns check >"$log" 2>&1; then
    fail 'ADB discovery is unavailable. Try adb kill-server, then launch Phone Control again.'
fi

serial=''
# Accept mDNS and explicit IP transports, never USB devices. If automatic
# connection fails, try advertised TLS endpoints (including collision names).
for ((attempt = 0; attempt < 12; attempt++)); do
    if ! devices=$(adb devices 2>"$log"); then
        fail 'Could not list ADB devices.'
    fi
    # ADB separates serial and state with a tab. mDNS names can contain spaces
    # (for example, a collision suffix " (2)"), so whitespace splitting is unsafe.
    mapfile -t phones < <(printf '%s\n' "$devices" | awk -F '\t' '
        $2 == "device" && ($1 ~ /\._adb-tls-connect\._tcp$/ ||
            $1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$/ ||
            $1 ~ /^\[[0-9a-fA-F:%.]+\]:[0-9]+$/) {
            print $1
        }
    ')
    phone_identity=''
    for candidate in "${phones[@]}"; do
        # ADB may expose the same phone through both an IP endpoint and mDNS
        # aliases. Probe each transport before comparing device identities.
        if ! identity=$(timeout 3 adb -s "$candidate" shell getprop ro.serialno 9>&- 2>"$log"); then
            continue
        fi
        identity=${identity//$'\r'/}
        [[ -n "$identity" && "$identity" != unknown ]] || fail 'Could not identify a wireless phone safely. Check its ADB connection, then try again.'
        if [[ -n "$phone_identity" && "$identity" != "$phone_identity" ]]; then
            fail 'Multiple different wireless phones are connected. Disconnect the others, then try again.'
        fi
        phone_identity="$identity"
        # Prefer a responsive mDNS alias over an explicit IP/port connection.
        if [[ -z "$serial" || ( "$serial" != *._adb-tls-connect._tcp && "$candidate" == *._adb-tls-connect._tcp ) ]]; then
            serial="$candidate"
        fi
    done
    [[ -z "$serial" ]] || break
    if ((attempt == 0)); then
        mapfile -t endpoints < <(adb mdns services 2>"$log" | awk '
            $(NF - 1) == "_adb-tls-connect._tcp" { print $NF }
        ' | sort -u)
        for endpoint in "${endpoints[@]}"; do
            timeout 3 adb connect "$endpoint" 9>&- >"$log" 2>&1 || true
        done
    fi
    sleep 1
done

[[ -n "$serial" ]] || fail 'No matching paired phone found. Connect it to the same Wi-Fi and enable Developer options → Wireless debugging (it turns off after reboot). Pair it once if this PC is not already trusted.'

lock_state() {
    local state
    if ! state=$(adb -s "$serial" shell "dumpsys trust | grep '(current):'" 2>"$log"); then
        fail 'Could not check whether the phone is locked.'
    fi
    if [[ "$state" =~ deviceLocked=([01]) ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
    else
        fail 'Unknown phone lock state; no PIN was sent.'
    fi
}

if [[ -n "$pin_file" ]]; then
    state=$(lock_state)
    if [[ "$state" == 1 ]]; then
        if ! size=$(adb -s "$serial" shell wm size 2>"$log" | awk '/size:/ {size = $NF} END {print size}'); then
            fail 'Could not determine the phone screen size; no PIN was sent.'
        fi
        [[ "$size" =~ ^([0-9]+)x([0-9]+)$ ]] || fail 'Unknown screen size; no PIN was sent.'
        width=${BASH_REMATCH[1]}
        height=${BASH_REMATCH[2]}
        ready=false
        for ((attempt = 0; attempt < 4; attempt++)); do
            if ! adb -s "$serial" shell "input keyevent KEYCODE_WAKEUP; sleep 0.3; input swipe $((width / 2)) $((height * 10 / 13)) $((width / 2)) $((height * 5 / 26)) 200" >"$log" 2>&1; then
                fail 'Could not open PIN entry; no PIN was sent.'
            fi
            if ! bouncer=$(adb -s "$serial" shell 'dumpsys activity service com.android.systemui/.SystemUIService | grep mBouncerShowing=' 2>"$log"); then
                fail 'Could not verify the PIN screen; no PIN was sent.'
            fi
            if [[ "$bouncer" == *mBouncerShowing=true* ]]; then
                ready=true
                break
            fi
        done
        [[ "$ready" == true ]] || fail 'The PIN screen did not open; no PIN was sent.'
        [[ -r "$pin_file" ]] || fail 'The phone PIN secret is unavailable. Check the sops-nix user service.'
        pin=$(< "$pin_file")
        [[ "$pin" =~ ^[0-9]{4,16}$ ]] || fail 'The phone PIN secret must contain 4–16 digits.'
        # Clear stale input and send exactly once. The PIN travels on stdin, not
        # in the host process arguments, generated script, or logs.
        # shellcheck disable=SC2016 # Expand $pin on the phone, not on the PC.
        if ! printf '%s\n' "$pin" | adb -s "$serial" shell '
            IFS= read -r pin || exit 1
            case "$pin" in ""|*[!0-9]*) exit 1 ;; esac
            input keyevent 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67
            input text "$pin"
            input keyevent KEYCODE_ENTER
        ' >/dev/null 2>&1; then
            unset pin
            fail 'PIN submission failed; it will not be retried automatically.'
        fi
        unset pin
        unlocked=false
        for ((attempt = 0; attempt < 40; attempt++)); do
            state=$(lock_state)
            if [[ "$state" == 0 ]]; then
                unlocked=true
                break
            fi
            sleep 0.05
        done
        [[ "$unlocked" == true ]] || fail 'The phone did not unlock. Check it manually; the PIN will not be retried automatically.'
    fi
fi

# Notification setup must not delay the scrcpy window or retain its session lock.
# A separate lock avoids overlapping provisioning if a session is reopened quickly.
if [[ -n "${relay_provision:-}" ]]; then
    (
        exec 9>&-
        exec 8>"$runtime_dir/phone-control-relay.lock"
        flock -n 8 || exit 0
        if ! python3 "$relay_provision" "$serial" "$relay_port" 8>&- >/dev/null 2>&1; then
            notify-send --app-name='Phone Control' --icon=smartphone --urgency=critical \
                'Notification setup failed' 'Update the phone helper and check Wi-Fi. Phone control will still open.' 8>&- || true
        fi
    ) &
fi

scrcpy_command=(scrcpy --serial="$serial" --window-title='Phone Control' --window-width=499 --window-height=1072 --keyboard=uhid --turn-screen-off --keep-active --video-codec=h265 --video-bit-rate=16M --max-size=2340 "${scrcpy_args[@]}")
if $monitor; then
    if SDL_APP_ID=phone-control python3 "$monitor_script" "$serial" -- "${scrcpy_command[@]}" 2>&1 | tee --ignore-interrupts "$log"; then
        exit 0
    fi
else
    if SDL_APP_ID=phone-control "${scrcpy_command[@]}" >"$log" 2>&1; then
        exit 0
    fi
fi
cat "$log" >&2
fail 'The phone-control session failed. Check Wi-Fi and Wireless debugging, then try again.'
