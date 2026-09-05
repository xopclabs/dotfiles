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

# Common media extensions (default filter)
MEDIA_EXTS=(
    # Video
    mp4 mkv avi mov wmv flv webm m4v mpg mpeg ts m2ts
    # Audio
    mp3 flac wav aac ogg m4a wma opus
    # Image
    jpg jpeg png gif webp bmp tiff
)

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
            INCLUDE_PATS+=("$2")
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

# Apply default media filter if no --only/--include was specified
if [ ${#INCLUDE_PATS[@]} -eq 0 ]; then
    RSYNC_FILTERS+=("--include=*/")
    for ext in "${MEDIA_EXTS[@]}"; do
        RSYNC_FILTERS+=("--include=*.$ext" "--include=*.${ext^^}")
        INCLUDE_PATS+=("*.$ext" "*.${ext^^}")
    done
    RSYNC_FILTERS+=("--exclude=*")
fi

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

##################### 4. helper: find filtered files ##########################
find_filtered_files() {
    local dir="$1"
    local find_args=("$dir" -type f)

    if [ ${#INCLUDE_PATS[@]} -gt 0 ]; then
        find_args+=("(")
        local first=1
        for pat in "${INCLUDE_PATS[@]}"; do
            [ "$first" -eq 1 ] || find_args+=(-o)
            find_args+=(-name "$pat")
            first=0
        done
        find_args+=(")")
    fi
    for pat in "${EXCLUDE_PATS[@]}"; do
        find_args+=(! -name "$pat")
    done

    find "${find_args[@]}" | sort
}

##################### 5. stream vs save ######################################
if [ "$SAVE" -eq 1 ]; then
    # Build rsync options
    RSYNC_OPTS=(-avPL)
    if [ "$SYNC" -eq 1 ]; then
        # --delete-excluded ensures non-media files are also removed
        RSYNC_OPTS+=(--delete --delete-excluded)
    fi

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

        # Play only filtered files if filters are set
        if [ ${#INCLUDE_PATS[@]} -gt 0 ] || [ ${#EXCLUDE_PATS[@]} -gt 0 ]; then
            mapfile -t FILES < <(find_filtered_files "$RSYNC_DST")
            if [ ${#FILES[@]} -eq 0 ]; then
                echo "No files matched the filter"
                exit 1
            fi
            echo "→ playing ${#FILES[@]} matching files"
            mpv -- "${FILES[@]}"
        else
            mpv -- "$RSYNC_DST"
        fi
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
    if [ ${#INCLUDE_PATS[@]} -gt 0 ] || [ ${#EXCLUDE_PATS[@]} -gt 0 ]; then
        if [ -d "$LOCAL_PATH" ]; then
            mapfile -t FILES < <(find_filtered_files "$LOCAL_PATH")
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
