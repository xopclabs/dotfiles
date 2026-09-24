#!/usr/bin/env bash
# Single owner for both session startup and bar-restart.
set -euo pipefail

eww=$1
config=$2
flock=$3
shift 3
restart=false
if [[ ${1:-} == --restart ]]; then
    restart=true
    shift
fi
[[ ${1:-} == -- ]] || exit 2
shift

# CLI children (especially `eww daemon`) must not inherit the lock FD.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/eww-dashboard.lock"
"$flock" -w 15 9

if $restart; then
    "$eww" --config "$config" kill 9>&- >/dev/null 2>&1 || true
    for ((i = 0; i < 50; i++)); do
        if ! "$eww" --config "$config" ping 9>&- >/dev/null 2>&1; then
            break
        fi
        sleep 0.1
    done
    if "$eww" --config "$config" ping 9>&- >/dev/null 2>&1; then
        echo "Eww daemon did not stop" >&2
        exit 1
    fi
fi

if ! "$eww" --config "$config" ping 9>&- >/dev/null 2>&1; then
    "$eww" --config "$config" daemon 9>&- >/dev/null
    for ((i = 0; i < 50; i++)); do
        if "$eww" --config "$config" ping 9>&- >/dev/null 2>&1; then
            break
        fi
        sleep 0.1
    done
    if ! "$eww" --config "$config" ping 9>&- >/dev/null 2>&1; then
        echo "Eww daemon did not start" >&2
        exit 1
    fi
fi

# Eww starts referenced defpolls when their windows open. A separate `poll`
# here can double the first fetch and contend with queries on startup.
if [[ -z $("$eww" --config "$config" active-windows 9>&-) ]]; then
    "$eww" --config "$config" open-many "$@" 9>&-
fi
