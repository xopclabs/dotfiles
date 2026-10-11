# Never trace secret reads or PIN submission, even if invoked with bash -x.
set +x
umask 077
# Injected by the Nix wrapper; neither variable contains the PIN.
expected_serial="${expected_serial:-}"
pin_file="${pin_file:-}"

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
    notify-send --app-name='Phone Control' --icon=smartphone \
        'Phone Control' 'A phone-control session is already running.' || true
    exit 0
fi

log=$(mktemp "$runtime_dir/phone-control.XXXXXX")
trap 'rm -f "$log"; unset pin' EXIT

if ! adb start-server >"$log" 2>&1; then
    fail 'Could not start ADB. Run phone-control in a terminal to diagnose it.'
fi
if ! adb mdns check >"$log" 2>&1; then
    fail 'ADB discovery is unavailable. Try adb kill-server, then launch Phone Control again.'
fi

serial=''
# ADB discovers and authenticates previously paired phones via mDNS.
# Only select wireless transports; do not accidentally open a USB webcam phone.
for ((attempt = 0; attempt < 12; attempt++)); do
    if ! devices=$(adb devices 2>"$log"); then
        fail 'Could not list ADB devices.'
    fi
    mapfile -t phones < <(printf '%s\n' "$devices" | awk '
        $2 == "device" && ($1 ~ /\._adb-tls-connect\._tcp$/ || $1 ~ /:[0-9]+$/) {
            print $1
        }
    ')
    for candidate in "${phones[@]}"; do
        if [[ -n "$expected_serial" ]]; then
            if ! actual_serial=$(adb -s "$candidate" shell getprop ro.serialno 2>"$log"); then
                continue
            fi
            [[ "${actual_serial//$'\r'/}" == "$expected_serial" ]] || continue
        fi
        [[ -z "$serial" ]] || fail 'Multiple matching wireless phones are connected. Disconnect the others, then try again.'
        serial="$candidate"
    done
    [[ -z "$serial" ]] || break
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
    [[ -n "$expected_serial" ]] || fail 'Automatic unlock requires a configured phone serial; no PIN was sent.'
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

if SDL_APP_ID=phone-control scrcpy --serial="$serial" --window-title='Phone Control' --window-width=499 --window-height=1072 --keyboard=uhid --turn-screen-off "$@" >"$log" 2>&1; then
    exit 0
fi
cat "$log" >&2
fail 'The phone-control session failed. Check Wi-Fi and Wireless debugging, then try again.'
