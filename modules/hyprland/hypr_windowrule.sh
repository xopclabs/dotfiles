# Print debug info to stderr
log() {
  echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

windowtitlev2() {
  log "Received windowtitlev2 event: $1"
  
  IFS=',' read -r -a args <<< "$1"
  args[0]="${args[0]#*>>}"
  
  log "Window ID: 0x${args[0]}, Title: ${args[1]}"

  if [[ ${args[1]} == "Extension: (Bitwarden Password Manager) - Bitwarden — Mozilla Firefox" ]]; then
    log "Bitwarden window detected, applying floating rules"
    hyprctl --batch "\
      dispatch setfloating address:0x${args[0]}; \
      dispatch pin address:0x${args[0]}; \
      dispatch resizeactive exact 20% 50%; \
      dispatch moveactive exact $(hyprctl cursorpos | tr -d ','); \
    "
  elif [[ ${args[1]} =~ ^Composer\ -\ .*\ -\ Cursor$ ]]; then
    log "Composer window detected, moving to workspace 5"
    # Save current workspace before switching
    current_workspace=$(hyprctl activeworkspace | grep "workspace ID" | awk '{print $3}')
    log "Current workspace: $current_workspace"
    
    hyprctl --batch "\
      dispatch movetoworkspace 5,address:0x${args[0]}; \
      dispatch workspace $current_workspace; \
    "
    log "Returned to workspace $current_workspace"
  else
    log "No rules applied for this window"
  fi
}

handle() {
  log "Handling event: $1"
  case $1 in
    windowtitlev2\>*) windowtitlev2 "$1" ;;
    *) log "Ignoring unhandled event type" ;;
  esac
}

log "Starting Hyprland window rule handler"
log "Connecting to Hyprland socket..."

socat -U - UNIX-CONNECT:"/$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" \
  | while read -r line; do handle "$line"; done
