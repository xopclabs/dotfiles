#!/usr/bin/env bash

session="${1:-}"
managed="${2:-}"
owned_window="${3:-}"

[ -z "$session" ] && exit 0

window_is_untouched() {
    local window_id="$1"
    local num_panes pane_id pane_dead cmd pane_pid capture line_count

    # Window IDs are stable across index renumbering. If any query is
    # ambiguous or fails, preserve the window.
    num_panes=$(tmux display-message -p -t "$window_id" '#{window_panes}' 2>/dev/null) || return 1
    [ "$num_panes" -eq 1 ] || return 1

    pane_id=$(tmux display-message -p -t "$window_id" '#{pane_id}' 2>/dev/null) || return 1
    [ -n "$pane_id" ] || return 1

    pane_dead=$(tmux display-message -p -t "$pane_id" '#{pane_dead}' 2>/dev/null) || return 1
    [ "$pane_dead" -eq 0 ] || return 1

    # A foreground program or TUI always makes the window persistent.
    cmd=$(tmux display-message -p -t "$pane_id" '#{pane_current_command}' 2>/dev/null) || return 1
    case "$cmd" in
        zsh|bash|sh|fish) ;;
        *) return 1 ;;
    esac

    # Preserve shells with direct background children.
    pane_pid=$(tmux display-message -p -t "$pane_id" '#{pane_pid}' 2>/dev/null) || return 1
    [ -n "$pane_pid" ] || return 1
    if pgrep -P "$pane_pid" >/dev/null 2>&1; then
        return 1
    fi

    # The configured Starship prompt is one line ending in ➜. Looking at all
    # history preserves both commands that returned to the prompt and text
    # currently typed but not executed. Startup output or anything uncertain
    # is intentionally treated as used.
    capture=$(tmux capture-pane -S - -p -t "$pane_id" 2>/dev/null) || return 1
    capture=$(printf '%s\n' "$capture" | sed '/^[[:space:]]*$/d')
    line_count=$(printf '%s\n' "$capture" | grep -c .)

    if [ "$line_count" -eq 0 ]; then
        return 0
    fi
    if [ "$line_count" -eq 1 ] && printf '%s\n' "$capture" | grep -Eq '[➜❯$%#>][[:space:]]*$'; then
        return 0
    fi
    return 1
}

if [ "$managed" = "1" ]; then
    case "$owned_window" in
        @*) ;;
        *) exit 0 ;;
    esac

    # Managed sessions deliberately do not use destroy-unattached: tmux 3.7c
    # destroys such a session before client-detached formats are expanded.
    # The hook passes its metadata here while the session still exists, and
    # this helper provides the equivalent linked-session cleanup.
    if [ "$(tmux display-message -p -t "$session" '#{@niri_managed}' 2>/dev/null)" != "1" ] ||
       [ "$(tmux display-message -p -t "$session" '#{@niri_window}' 2>/dev/null)" != "$owned_window" ] ||
       [ "$(tmux display-message -p -t "$session" '#{session_attached}' 2>/dev/null)" != "0" ]; then
        exit 0
    fi

    tmux kill-session -t "$session" 2>/dev/null || exit 0
    if window_is_untouched "$owned_window"; then
        tmux kill-window -t "$owned_window" 2>/dev/null
    fi
    exit 0
fi

# Preserve the original session-oriented cleanup for ordinary tm clients.
if ! tmux has-session -t "$session" 2>/dev/null; then
    exit 0
fi

attached=$(tmux display-message -p -t "$session" '#{session_attached}' 2>/dev/null)
if [ "${attached:-1}" -ne 0 ]; then
    exit 0
fi

group_attached=$(tmux display-message -p -t "$session" '#{?session_grouped,#{session_group_attached},0}' 2>/dev/null)
if [ "${group_attached:-0}" -ne 0 ]; then
    exit 0
fi

num_windows=$(tmux display-message -p -t "$session" '#{session_windows}' 2>/dev/null)
if [ "${num_windows:-0}" -ne 1 ]; then
    exit 0
fi

if window_is_untouched "$session"; then
    tmux kill-session -t "$session" 2>/dev/null
fi
