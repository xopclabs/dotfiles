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
    # If already in tmux, run the session manager
    $(tmux list-keys | grep sessionx.sh | awk '{print $NF}')
    exit 0
fi

# Check if tmux is running and has sessions
if tmux has-session 2>/dev/null; then
    # Count the number of tmux sessions
    session_count=$(tmux list-sessions | wc -l)

    # Check if connected via SSH
    if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_TTY" ]; then
        # When connected via SSH, just attach without session manager
        tmux attach-session
    # Check if there is more than 1 session
    elif [ "$session_count" -gt 1 ]; then
        # If there are multiple sessions, attach and run session manager
        tmux new-session -As "$session_name" \; run-shell "$(tmux list-keys | grep sessionx.sh | awk '{print $NF}')"
    else
        # If there is only one session, just attach
        tmux attach-session
    fi
else
    # No tmux sessions, create a new one
    tmux new-session -s "$session_name"
fi

