##############################################################################
# remotempv – stream or save‑and‑play remote videos with sshfs / rsync + mpv #
# Works in both bash and zsh (emulating POSIX sh).                           #
##############################################################################

set -euo pipefail

##################### 1. argument parsing #####################################
SAVE=0
SYNC=0
SAVE_DEST=""
REMOTE=""
RSYNC_FILTERS=()
INCLUDE_PATS=()
EXCLUDE_PATS=()
ONLY_PAT=""

while [ $# -gt 0 ]; do
    case "$1" in
        --save) SAVE=1; shift ;;
        --sync) SAVE=1; SYNC=1; shift ;;  # --sync implies --save
        --exclude)
            RSYNC_FILTERS+=("--exclude=$2")
            EXCLUDE_PATS+=("$2")
            shift 2 ;;
        --include)
            RSYNC_FILTERS+=("--include=$2")
            INCLUDE_PATS+=("$2")
            shift 2 ;;
        --only)
            # Shorthand: include dirs for traversal, include pattern, exclude rest
            RSYNC_FILTERS+=("--include=*/")
            RSYNC_FILTERS+=("--include=$2")
            RSYNC_FILTERS+=("--exclude=*")
            ONLY_PAT="$2"
            shift 2 ;;
        --*) shift ;;  # ignore unknown flags
        *)
            if [ -z "$REMOTE" ]; then
                REMOTE="$1"
            elif [ -z "$SAVE_DEST" ]; then
                SAVE_DEST="$1"
            fi
            shift ;;
    esac
done

[ -n "${REMOTE-}" ] || { echo "Usage: remotempv host:/abs/path [--save|--sync [dest]] [--include PAT] [--exclude PAT] [--only PAT]"; exit 2; }

##################### 2. split “host:/path” ##################################
HOST=${REMOTE%%:*}
RPATH=${REMOTE#*:}
case "$RPATH" in /*) ;; *) echo "Path must be absolute"; exit 2;; esac

##################### 3. per‑host mountpoint #################################
BASE_MP="${XDG_RUNTIME_DIR:-$HOME/.cache}/remotempv"
MP="$BASE_MP/$HOST"
mkdir -p "$MP"

if ! mountpoint -q "$MP"; then
    echo "→ mounting sshfs $HOST at $MP"
    sshfs "$HOST:/" "$MP" \
          -o reconnect,delay_connect,ServerAliveInterval=15 \
          -o cache=yes,attr_timeout=5,follow_symlinks,no_readahead
fi

##################### 4. stream vs save ######################################
if [ "$SAVE" -eq 1 ]; then
    # Build rsync options
    RSYNC_OPTS=(-avPL)
    [ "$SYNC" -eq 1 ] && RSYNC_OPTS+=(--delete)

    if ssh "$HOST" "test -d \"$RPATH\""; then
        # remote is a directory
        RSYNC_SRC="$HOST:$RPATH/"
        if [ -n "$SAVE_DEST" ]; then
            RSYNC_DST="$SAVE_DEST/"
        else
            RSYNC_DST="$HOME/videos/$(basename "$RPATH")/"
        fi
        mkdir -p "$RSYNC_DST"
        if [ "$SYNC" -eq 1 ]; then
            echo "→ syncing directory to $RSYNC_DST (deleting extras)"
        else
            echo "→ rsyncing directory to $RSYNC_DST"
        fi
        rsync "${RSYNC_OPTS[@]}" "${RSYNC_FILTERS[@]}" "$RSYNC_SRC" "$RSYNC_DST"
        mpv -- "$RSYNC_DST"
    else
        # remote is a single file
        RSYNC_SRC="$HOST:$RPATH"
        if [ -n "$SAVE_DEST" ]; then
            mkdir -p "$(dirname "$SAVE_DEST")"
            LOCAL="$SAVE_DEST"
        else
            mkdir -p "$HOME/videos"
            LOCAL="$HOME/videos/$(basename "$RPATH")"
        fi
        echo "→ rsyncing file to $LOCAL"
        rsync "${RSYNC_OPTS[@]}" "${RSYNC_FILTERS[@]}" "$RSYNC_SRC" "$LOCAL"
        mpv -- "$LOCAL"
    fi
else
    echo "→ streaming via sshfs"
    LOCAL_PATH="$MP$RPATH"

    # Check if we need filtering (only works for directories)
    if [ -n "$ONLY_PAT" ] || [ ${#INCLUDE_PATS[@]} -gt 0 ] || [ ${#EXCLUDE_PATS[@]} -gt 0 ]; then
        if [ -d "$LOCAL_PATH" ]; then
            # Build find command with filters
            FIND_ARGS=("$LOCAL_PATH" -type f)

            if [ -n "$ONLY_PAT" ]; then
                # --only: match only this pattern
                FIND_ARGS+=(-name "$ONLY_PAT")
            else
                # Build include/exclude logic
                # Includes: match any of the patterns (OR)
                if [ ${#INCLUDE_PATS[@]} -gt 0 ]; then
                    FIND_ARGS+=("(")
                    first=1
                    for pat in "${INCLUDE_PATS[@]}"; do
                        [ "$first" -eq 1 ] || FIND_ARGS+=(-o)
                        FIND_ARGS+=(-name "$pat")
                        first=0
                    done
                    FIND_ARGS+=(")")
                fi
                # Excludes: reject any of the patterns
                for pat in "${EXCLUDE_PATS[@]}"; do
                    FIND_ARGS+=(! -name "$pat")
                done
            fi

            # Find files and play them
            mapfile -t FILES < <(find "${FIND_ARGS[@]}" | sort)
            if [ ${#FILES[@]} -eq 0 ]; then
                echo "No files matched the filter"
                exit 1
            fi
            echo "→ found ${#FILES[@]} matching files"
            mpv -- "${FILES[@]}"
        else
            # Single file, filters don't apply
            mpv -- "$LOCAL_PATH"
        fi
    else
        mpv -- "$LOCAL_PATH"
    fi
fi
