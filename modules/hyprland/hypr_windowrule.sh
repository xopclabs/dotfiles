windowtitlev2() {
  IFS=',' read -r -a args <<< "$1"
  args[0]="${args[0]#*>>}"

  if [[ ${args[1]} == "Extension: (Bitwarden Password Manager) - Bitwarden — Mozilla Firefox" ]]; then
    hyprctl --batch "\
      dispatch setfloating address:0x${args[0]}; \
      dispatch pin address:0x${args[0]}; \
      dispatch resizeactive exact 20% 50%; \
      dispatch moveactive exact $(hyprctl cursorpos | tr -d ','); \
    "
  fi
}

handle() {
  case $1 in
    windowtitlev2\>*) windowtitlev2 "$1" ;;
  esac
}

socat -U - UNIX-CONNECT:"/$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" \
  | while read -r line; do handle "$line"; done
