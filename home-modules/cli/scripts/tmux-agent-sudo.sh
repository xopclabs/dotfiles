#!/usr/bin/env bash
set -euo pipefail

if [[ -z ${TMUX:-} ]]; then
    printf 'Run tmux-agent-sudo inside tmux.\n' >&2
    exit 1
fi

if [[ ${1:-} != --pane ]]; then
    printf -v command '%q --pane' "$0"
    session=$(tmux display-message -p '#{client_session}')
    if [[ -z $session ]]; then
        session=$(tmux display-message -p '#{session_name}')
    fi
    pane=$(tmux new-window -t "$session:" -P -F '#{pane_id}' -n agent+sudo -c "$PWD" "$command")
    tmux select-window -t "$pane"
    tmux select-pane -t "$pane"
    exit 0
fi

window=$(tmux display-message -p -t "$TMUX_PANE" '#{window_id}')
tmux set-option -w -t "$window" @agent_sudo 1
tmux set-option -w -t "$window" automatic-rename off
for option in window-status-format window-status-current-format; do
    format=$(tmux show-options -g -v "$option")
    format=${format//${TMUX_AGENT_SUDO_BLUE:-#81a1c1}/${TMUX_AGENT_SUDO_RED:-#bf616a}}
    format=${format//${TMUX_AGENT_SUDO_YELLOW:-#ebcb8b}/${TMUX_AGENT_SUDO_RED:-#bf616a}}
    if [[ $option == window-status-current-format ]]; then
        format=${format//nobold/bold}
    fi
    tmux set-option -w -t "$window" "$option" "$format"
done

cleanup() { sudo -k || true; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

printf '\nDedicated agent terminal with terminal-scoped sudo.\n'
printf 'Red means sudo-capable agent window, not guaranteed active authentication.\n'
printf 'Authenticate here; agent commands use sudo -n.\n'
printf 'Exit this shell to revoke this terminal’s cached authorization.\n\n'
sudo -k
if ! sudo -v; then
    printf '\nAuthentication failed; closing agent sudo pane.\n' >&2
    exit 1
fi
printf '\nAuthenticated. Normal user shell; sudo timeout still applies.\n\n'
"${TMUX_AGENT_SUDO_SHELL:-${SHELL:-/bin/sh}}" -i
