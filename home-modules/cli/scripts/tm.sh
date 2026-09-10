#!/usr/bin/env bash

# Parse arguments
suffix=""
use_workspace=false
niri_managed=false
while getopts "np:w" opt; do
    case $opt in
        p)
            suffix="-${OPTARG}"
            ;;
        w)
            use_workspace=true
            ;;
        n)
            niri_managed=true
            ;;
        *)
            echo "Usage: tm [-w] [-n] [-p suffix]"
            exit 1
            ;;
    esac
done

get_wm() {
    local desktop_lower
    desktop_lower=$(echo "${XDG_CURRENT_DESKTOP:-}" | tr '[:upper:]' '[:lower:]')
    case "$desktop_lower" in
        *niri*) echo "niri" ;;
        *hyprland*) echo "hyprland" ;;
        *sway*) echo "sway" ;;
        *i3*) echo "i3" ;;
        *)
            if [ -n "${NIRI_SOCKET:-}" ]; then
                echo "niri"
            elif [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
                echo "hyprland"
            elif [ -n "${SWAYSOCK:-}" ]; then
                echo "sway"
            elif [ -n "${I3SOCK:-}" ]; then
                echo "i3"
            else
                echo "unknown"
            fi
            ;;
    esac
}

get_workspace_niri() {
    if ! command -v niri >/dev/null 2>&1; then
        return 1
    fi
    local focused_mon ws
    focused_mon=$(niri msg --json focused-output 2>/dev/null | jq -r '.name // empty' 2>/dev/null)
    ws=$(niri msg --json workspaces 2>/dev/null | jq -r --arg mon "$focused_mon" '
        (.[] | select(.is_focused)).idx //
        (.[] | select(.output == $mon and .is_active)).idx //
        (.[] | select(.is_active)).idx //
        empty
    ' 2>/dev/null | head -n 1)
    if [ -n "$ws" ]; then
        echo "$ws"
        return 0
    fi
    return 1
}

get_workspace_hyprland() {
    if ! command -v hyprctl >/dev/null 2>&1; then
        return 1
    fi
    local ws
    if command -v jq >/dev/null 2>&1; then
        ws=$(hyprctl activeworkspace -j 2>/dev/null | jq -r 'if (.id // 0) > 0 then .id else empty end' 2>/dev/null)
        if [ -z "$ws" ]; then
            ws=$(hyprctl monitors -j 2>/dev/null | jq -r '(.[] | select(.focused)).activeWorkspace.id // empty' 2>/dev/null | head -n 1)
        fi
    fi
    if [ -z "$ws" ]; then
        ws=$(hyprctl activeworkspace 2>/dev/null | awk '/workspace ID/ {print $3}' | tr -dc '0-9')
    fi
    if [ -n "$ws" ]; then
        echo "$ws"
        return 0
    fi
    return 1
}

get_workspace_sway() {
    if ! command -v swaymsg >/dev/null 2>&1; then
        return 1
    fi
    local ws
    if command -v jq >/dev/null 2>&1; then
        ws=$(swaymsg -t get_workspaces 2>/dev/null | jq -r '(.[] | select(.focused)).num // empty' 2>/dev/null | head -n 1)
    fi
    if [ -n "$ws" ]; then
        echo "$ws"
        return 0
    fi
    return 1
}

get_workspace_i3() {
    if ! command -v i3-msg >/dev/null 2>&1; then
        return 1
    fi
    local ws
    if command -v jq >/dev/null 2>&1; then
        ws=$(i3-msg -t get_workspaces 2>/dev/null | jq -r '(.[] | select(.focused)).num // empty' 2>/dev/null | head -n 1)
    fi
    if [ -n "$ws" ]; then
        echo "$ws"
        return 0
    fi
    return 1
}

get_workspace() {
    local wm
    wm=$(get_wm)
    case "$wm" in
        niri) get_workspace_niri ;;
        hyprland) get_workspace_hyprland ;;
        sway) get_workspace_sway ;;
        i3) get_workspace_i3 ;;
        *)
            get_workspace_niri || get_workspace_hyprland || get_workspace_sway || get_workspace_i3 || return 1
            ;;
    esac
}

# Define session name
if [ "$use_workspace" = true ]; then
    ws=$(get_workspace)
    if [ -n "$ws" ]; then
        session_name="${ws}${suffix}"
    else
        session_name="main${suffix}"
    fi
else
    session_name="main${suffix}"
fi

sessionx_cmd() {
    tmux list-keys | grep sessionx.sh | awk '{print $NF}'
}

# Check if we're already in a tmux session
if [ -n "$TMUX" ]; then
    if [ "$niri_managed" = true ]; then
        echo "tm: -n must be launched as a new terminal, not from inside tmux" >&2
        exit 1
    fi
    if [ "$use_workspace" = true ]; then
        if ! tmux has-session -t "$session_name" 2>/dev/null; then
            tmux new-session -d -s "$session_name"
        fi
        tmux switch-client -t "$session_name"
        exit 0
    else
        $(sessionx_cmd)
        exit 0
    fi
fi

# Find an unattached linked session in the same group as $session_name
# (excludes the base session itself)
find_orphan() {
    tmux list-sessions -F '#{session_name} #{session_group} #{session_attached} #{@niri_managed}' 2>/dev/null | \
        awk -v base="$session_name" '$2 == base && $3 == "0" && $1 != base && $4 != "1" {print $1; exit}'
}

# Find the lowest available index for a linked session name (e.g. main~1, main~2)
next_link_name() {
    local existing
    existing=$(tmux list-sessions -F '#{session_name}' 2>/dev/null)
    local i=1
    while echo "$existing" | grep -qx "${session_name}~${i}"; do
        i=$((i + 1))
    done
    echo "${session_name}~${i}"
}

# Reuse an orphaned linked session or create a new one.
# Extra tmux commands (e.g. \; run-shell "...") can be passed as arguments.
attach_or_link() {
    local orphan
    orphan=$(find_orphan)
    if [ -n "$orphan" ]; then
        tmux attach-session -t "$orphan" "$@"
    else
        local link_name
        link_name=$(next_link_name)
        tmux new-session -s "$link_name" -t "$session_name" \; set-option destroy-unattached on "$@"
    fi
}

# Give a compositor-managed terminal its own linked session and its own window.
# The base session is the persistent backing store; only the linked session is
# attached, so selecting the new window cannot move another terminal client.
if [ "$niri_managed" = true ]; then
    if [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_TTY:-}" ]; then
        echo "tm: -n is only intended for local graphical terminals" >&2
        exit 1
    fi

    # tmux may assign the same next numeric index to concurrent new-window
    # requests. Retry until the winning request has finished and the next
    # index is available; ownership uses the returned stable window ID.
    create_managed_window() {
        local attempt=0
        while [ "$attempt" -lt 100 ]; do
            # The trailing colon targets the session rather than its current
            # window. Without it, tmux repeatedly tries current-index + 1 and
            # fails once that index already exists.
            if window_id=$(tmux new-window -d -P -F '#{window_id}' -t "=$session_name:" 2>/dev/null); then
                return 0
            fi
            attempt=$((attempt + 1))
            sleep 0.01
        done
        return 1
    }

    if tmux has-session -t "=$session_name" 2>/dev/null; then
        create_managed_window || exit 1
    else
        # new-session must create one window. Use it as this terminal's owned
        # window, avoiding a dummy window on a fresh workspace. If another
        # launcher won the race to create the base, add a window to that base.
        if ! window_id=$(tmux new-session -d -P -F '#{window_id}' -s "$session_name" 2>/dev/null); then
            create_managed_window || exit 1
        fi
    fi

    # Name allocation and creation must be retried together: several niri
    # launches may all observe the same available suffix. A failed creator
    # must never kill the linked session another launcher just created.
    link_name=""
    for _ in $(seq 1 100); do
        candidate=$(next_link_name)
        if tmux new-session -d -s "$candidate" -t "=$session_name" 2>/dev/null; then
            link_name="$candidate"
            break
        fi
        if ! tmux has-session -t "$candidate" 2>/dev/null; then
            break
        fi
    done

    if [ -z "$link_name" ]; then
        tmux kill-window -t "$window_id" 2>/dev/null
        exit 1
    fi

    if ! tmux set-option -t "$link_name" @niri_managed 1 ||
       ! tmux set-option -t "$link_name" @niri_window "$window_id" ||
       ! tmux select-window -t "$link_name:$window_id"; then
        tmux kill-session -t "$link_name" 2>/dev/null
        tmux kill-window -t "$window_id" 2>/dev/null
        exit 1
    fi

    # Set up the linked session completely before attaching. In particular,
    # this avoids tmux trying to attach while it is still linking and selecting
    # windows, which can fail against a long-running server with renumbering.
    if ! tmux attach-session -t "$link_name"; then
        tmux kill-session -t "$link_name" 2>/dev/null
        tmux kill-window -t "$window_id" 2>/dev/null
        exit 1
    fi
    exit 0
fi

if [ "$use_workspace" = true ]; then
    if tmux has-session 2>/dev/null; then
        if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_TTY" ]; then
            tmux attach-session -t "$session_name" 2>/dev/null || tmux new-session -s "$session_name"
        else
            target_clients=$(tmux display-message -t "$session_name" -p '#{session_attached}' 2>/dev/null)
            if ! tmux has-session -t "$session_name" 2>/dev/null; then
                tmux new-session -s "$session_name"
            elif [ "${target_clients:-0}" -eq 0 ]; then
                tmux attach-session -t "$session_name"
            else
                attach_or_link
            fi
        fi
    else
        tmux new-session -s "$session_name"
    fi
else
    if tmux has-session 2>/dev/null; then
        if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_TTY" ]; then
            tmux attach-session
        else
            unique_groups=$(tmux list-sessions -F '#{?session_group,#{session_group},#{session_name}}' | sort -u | wc -l)
            main_clients=$(tmux display-message -t "$session_name" -p '#{session_attached}' 2>/dev/null)

            if ! tmux has-session -t "$session_name" 2>/dev/null; then
                tmux new-session -s "$session_name" \; run-shell "$(sessionx_cmd)"
            elif [ "${main_clients:-0}" -eq 0 ] && [ "$unique_groups" -le 1 ]; then
                tmux attach-session -t "$session_name"
            elif [ "${main_clients:-0}" -eq 0 ] && [ "$unique_groups" -gt 1 ]; then
                tmux attach-session -t "$session_name" \; run-shell "$(sessionx_cmd)"
            elif [ "$unique_groups" -gt 1 ]; then
                attach_or_link \; run-shell "$(sessionx_cmd)"
            else
                attach_or_link
            fi
        fi
    else
        tmux new-session -s "$session_name"
    fi
fi
