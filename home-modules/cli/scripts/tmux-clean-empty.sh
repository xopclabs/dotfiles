#!/usr/bin/env bash

session="$1"
[ -z "$session" ] && exit 0

# Check if session still exists
if ! tmux has-session -t "$session" 2>/dev/null; then
    exit 0
fi

# Check if session has any attached clients remaining
attached=$(tmux display-message -p -t "$session" '#{session_attached}' 2>/dev/null)
if [ "${attached:-1}" -ne 0 ]; then
    exit 0
fi

# If part of a session group, ensure no other session in the group is attached
group_attached=$(tmux display-message -p -t "$session" '#{?session_grouped,#{session_group_attached},0}' 2>/dev/null)
if [ "${group_attached:-0}" -ne 0 ]; then
    exit 0
fi

# Ensure it only has 1 window and 1 pane
num_windows=$(tmux display-message -p -t "$session" '#{session_windows}' 2>/dev/null)
num_panes=$(tmux display-message -p -t "$session" '#{window_panes}' 2>/dev/null)
if [ "${num_windows:-0}" -ne 1 ] || [ "${num_panes:-0}" -ne 1 ]; then
    exit 0
fi

# Ensure the foreground command in the pane is just an interactive shell
cmd=$(tmux display-message -p -t "$session" '#{pane_current_command}' 2>/dev/null)
case "$cmd" in
    zsh|bash|sh|fish) ;;
    *) exit 0 ;;
esac

# Ensure the shell has no child processes running in the background
pane_pid=$(tmux display-message -p -t "$session" '#{pane_pid}' 2>/dev/null)
if [ -n "$pane_pid" ] && pgrep -P "$pane_pid" >/dev/null 2>&1; then
    exit 0
fi

# Capture the entire pane including history, ignoring whitespace-only lines
non_empty_lines=$(tmux capture-pane -S - -p -t "$session" 2>/dev/null | sed '/^[[:space:]]*$/d')
line_count=$(echo "$non_empty_lines" | grep -c .)

# A genuinely clean session has either 0 lines or exactly 1 prompt line with nothing typed after it
if [ "$line_count" -eq 1 ]; then
    if echo "$non_empty_lines" | grep -Eq '[➜❯$%#>][[:space:]]*$'; then
        tmux kill-session -t "$session" 2>/dev/null
    fi
elif [ "$line_count" -eq 0 ]; then
    tmux kill-session -t "$session" 2>/dev/null
fi
