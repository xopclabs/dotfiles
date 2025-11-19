# --- remotempv programmable completion (bash & zsh) -----------------
# Resolves   host:/path/...   into the local sshfs mount
#    $XDG_RUNTIME_DIR/remotempv/$host/path/...
# and completes files/dirs from there, rewriting suggestions back to
# the remote syntax so the command line still reads host:/…
# --------------------------------------------------------------------

# helper: translate remote spec → local path, but only if mounted
__remotempv_remote2local() {
  local spec=$1
  [[ $spec == *:* ]] || return 1
  local host=${spec%%:*}
  local rpath=${spec#*:}
  local mp="${XDG_RUNTIME_DIR:-$HOME/.cache}/remotempv/$host"
  mountpoint -q "$mp" || return 1
  printf '%s\n' "$mp$rpath"
}

# -------------------  bash  -----------------------------------------
if [[ -n ${BASH_VERSION:-} ]]; then
  _remotempv_complete() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    # Only fiddle with the 1st positional arg; leave --save etc. alone
    [[ $COMP_CWORD -ne 1 ]] && return 0

    local lpath
    if lpath=$(__remotempv_remote2local "$cur"); then
      # Generate candidate list from local fs
      local IFS=$'\n'
      local -a candidates=( $(compgen -f -- "$lpath") )
      # Rewrite to remote syntax
      local host=${cur%%:*} mp part
      for i in "${!candidates[@]}"; do
        part=${candidates[$i]#"${mp}/"}
        candidates[$i]="$host:$part"
      done
      COMPREPLY=("${candidates[@]}")
    fi
    return 0
  }
  complete -F _remotempv_complete remotempv
fi

# -------------------  zsh  ------------------------------------------
if [[ -n ${ZSH_VERSION:-} ]]; then
  emulate -L zsh
  _remotempv_complete() {
    local -a suggestions
    if [[ $words[2] == *:* ]]; then
      local lpath
      if lpath=$(__remotempv_remote2local "$words[2]"); then
        local host=${words[2]%%:*} mp=${lpath%${words[2]#*:}}
        # collect matches
        suggestions=( ${(f)"$(print -rl -- $lpath*(N))"} )
        # strip mount prefix, add host:/      ← the “:/” was missing
        suggestions=("${suggestions[@]#$mp/}")
        suggestions=("${suggestions[@]/#/$host:/}")
        compadd -- $suggestions
        return
      fi
    fi
    _files            # fallback to normal file completion
  }
  compdef _remotempv_complete remotempv
fi
