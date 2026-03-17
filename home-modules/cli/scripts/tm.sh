#!/usr/bin/env bash

# Parse arguments
suffix=""
while getopts "p:" opt; do
    case $opt in
        p)
            suffix="-${OPTARG}"
            ;;
        *)
            echo "Usage: tm [-p suffix]"
            exit 1
            ;;
    esac
done

# Define session name
session_name="main${suffix}"

# Check if we're already in a tmux session
if [ -n "$TMUX" ]; then
    $(tmux list-keys | grep sessionx.sh | awk '{print $NF}')
    exit 0
fi

sessionx_cmd() {
    tmux list-keys | grep sessionx.sh | awk '{print $NF}'
}

# Find an unattached linked session in the same group as $session_name
# (excludes the base session itself)
find_orphan() {
    tmux list-sessions -F '#{session_name} #{session_group} #{session_attached}' 2>/dev/null | \
        awk -v base="$session_name" '$2 == base && $3 == "0" && $1 != base {print $1; exit}'
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

if tmux has-session 2>/dev/null; then
    if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_TTY" ]; then
        tmux attach-session
    else
        unique_groups=$(tmux list-sessions -F '#{session_group}' | sort -u | wc -l)
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

