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

get_monitor_letter_niri() {
    if ! command -v niri >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        return 1
    fi
    local focused_mon letter
    focused_mon=$(niri msg --json focused-output 2>/dev/null | jq -r '.name // empty' 2>/dev/null)
    [ -n "$focused_mon" ] || return 1
    letter=$(niri msg --json outputs 2>/dev/null | jq -r --arg mon "$focused_mon" '
        to_entries
        | sort_by(.value.logical.y, .value.logical.x)
        | to_entries
        | .[]
        | select(.value.key == $mon)
        | ([97 + .key] | implode)
    ' 2>/dev/null | head -n 1)
    if [ -n "$letter" ]; then
        echo "$letter"
        return 0
    fi
    return 1
}

get_monitor_letter_hyprland() {
    if ! command -v hyprctl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        return 1
    fi
    local letter
    letter=$(hyprctl monitors -j 2>/dev/null | jq -r '
        sort_by(.y, .x)
        | to_entries
        | .[]
        | select(.value.focused)
        | ([97 + .key] | implode)
    ' 2>/dev/null | head -n 1)
    if [ -n "$letter" ]; then
        echo "$letter"
        return 0
    fi
    return 1
}

get_monitor_letter_sway() {
    if ! command -v swaymsg >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        return 1
    fi
    local letter
    letter=$(swaymsg -t get_outputs 2>/dev/null | jq -r '
        map(select(.active))
        | sort_by(.rect.y, .rect.x)
        | to_entries
        | .[]
        | select(.value.focused)
        | ([97 + .key] | implode)
    ' 2>/dev/null | head -n 1)
    if [ -n "$letter" ]; then
        echo "$letter"
        return 0
    fi
    return 1
}

get_monitor_letter_i3() {
    if ! command -v i3-msg >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        return 1
    fi
    local focused_output letter
    focused_output=$(i3-msg -t get_workspaces 2>/dev/null | jq -r '(.[] | select(.focused)).output // empty' 2>/dev/null | head -n 1)
    [ -n "$focused_output" ] || return 1
    letter=$(i3-msg -t get_outputs 2>/dev/null | jq -r --arg output "$focused_output" '
        map(select(.active))
        | sort_by(.rect.y, .rect.x)
        | to_entries
        | .[]
        | select(.value.name == $output)
        | ([97 + .key] | implode)
    ' 2>/dev/null | head -n 1)
    if [ -n "$letter" ]; then
        echo "$letter"
        return 0
    fi
    return 1
}

get_monitor_letter() {
    local wm
    wm=$(get_wm)
    case "$wm" in
        niri) get_monitor_letter_niri ;;
        hyprland) get_monitor_letter_hyprland ;;
        sway) get_monitor_letter_sway ;;
        i3) get_monitor_letter_i3 ;;
        *)
            get_monitor_letter_niri || get_monitor_letter_hyprland || get_monitor_letter_sway || return 1
            ;;
    esac
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
    monitor=$(get_monitor_letter)
    if [ -n "$ws" ]; then
        session_name="${monitor}${ws}${suffix}"
    else
        session_name="${monitor}main${suffix}"
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

# Give a compositor-managed terminal its own linked session. Prefer a window
# no other client is currently viewing; create a new window only when all
# existing windows in the session group are already attached somewhere.
if [ "$niri_managed" = true ]; then
    if [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_TTY:-}" ]; then
        echo "tm: -n is only intended for local graphical terminals" >&2
        exit 1
    fi

    if ! tmux has-session -t "=$session_name" 2>/dev/null; then
        tmux new-session -d -s "$session_name" 2>/dev/null || true
    fi
    if ! tmux has-session -t "=$session_name" 2>/dev/null; then
        exit 1
    fi

    find_unattached_window() {
        local group window_id
        group=$(tmux display-message -p -t "=$session_name" '#{session_group}' 2>/dev/null) || return 1
        tmux list-windows -t "=$session_name" -F '#{window_id}' 2>/dev/null | while read -r window_id; do
            if ! tmux list-clients -a -F '#{session_group} #{client_window_id}' 2>/dev/null | \
                awk -v group="$group" -v window_id="$window_id" '$1 == group && $2 == window_id {found = 1} END {exit found ? 0 : 1}'; then
                echo "$window_id"
                return 0
            fi
        done
    }

    create_managed_window() {
        local attempt=0
        while [ "$attempt" -lt 100 ]; do
            if tmux new-window -d -P -F '#{window_id}' -t "=$session_name:" 2>/dev/null; then
                return 0
            fi
            attempt=$((attempt + 1))
            sleep 0.01
        done
        return 1
    }

    create_linked_session() {
        local candidate
        for _ in $(seq 1 100); do
            candidate=$(next_link_name)
            if tmux new-session -d -s "$candidate" -t "=$session_name" 2>/dev/null; then
                echo "$candidate"
                return 0
            fi
            if ! tmux has-session -t "$candidate" 2>/dev/null; then
                return 1
            fi
        done
        return 1
    }

    window_id=$(find_unattached_window)
    owned_window=""
    if [ -z "$window_id" ]; then
        window_id=$(create_managed_window) || exit 1
        owned_window="$window_id"
    fi

    link_name=$(create_linked_session)
    if [ -z "$link_name" ]; then
        [ -n "$owned_window" ] && tmux kill-window -t "$owned_window" 2>/dev/null
        exit 1
    fi

    if ! tmux set-option -t "$link_name" @niri_managed 1 ||
       ! tmux set-option -t "$link_name" @niri_window "$owned_window" ||
       ! tmux select-window -t "$link_name:$window_id"; then
        tmux kill-session -t "$link_name" 2>/dev/null
        [ -n "$owned_window" ] && tmux kill-window -t "$owned_window" 2>/dev/null
        exit 1
    fi

    if ! tmux attach-session -t "$link_name"; then
        tmux kill-session -t "$link_name" 2>/dev/null
        [ -n "$owned_window" ] && tmux kill-window -t "$owned_window" 2>/dev/null
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
