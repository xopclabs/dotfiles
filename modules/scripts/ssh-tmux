# This script wraps the ssh command to rename tmux windows and panes.
# It prepends "ssh " to the destination (user@host or host) and then
# calls the ssh command with the provided arguments.

if [ -n "${TMUX:-}" ]; then
  dest_user_host=""

  # First, try to find an argument that includes an '@'
  for arg in "$@"; do
    if [[ "$arg" == *"@"* ]]; then
      dest_user_host="$arg"
      break
    fi
  done

  # If no user@host was found, use the first non-option argument (assumed to be the host)
  if [ -z "$dest_user_host" ]; then
    for arg in "$@"; do
      if [[ "$arg" != -* ]]; then
        dest_user_host="$arg"
        break
      fi
    done
  fi

  # If we found a destination, prepend "ssh " and rename tmux window/pane
  if [ -n "$dest_user_host" ]; then
    tmux_name="ssh $dest_user_host"
    (
      set +e  # Continue even if rename fails
      tmux display-message -p "#{pane_id}" > /dev/null && tmux rename-window "$tmux_name"
      tmux rename-pane "$tmux_name" 2>/dev/null || true
    ) &> /dev/null
  fi
fi

# Execute ssh with all provided arguments.
ssh "$@"

if [ -n "${TMUX:-}" ]; then
  tmux set-window-option automatic-rename on > /dev/null 2>&1 || true
fi

