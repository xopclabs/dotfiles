#!/usr/bin/env bash

# Default threshold for switching from eza to ls
THRESHOLD=512

# Parse arguments
ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# Get the directory to list (default to current directory)
# Find the directory from remaining arguments, or use current directory
DIR="."
for arg in "${ARGS[@]}"; do
    if [ -d "$arg" ]; then
        DIR="$arg"
        break
    fi
done

# Count files in the directory (including hidden files, excluding . and ..)
# Use a more efficient method that doesn't require globbing
if [ -d "$DIR" ]; then
    FILE_COUNT=$(find "$DIR" -mindepth 1 -maxdepth 1 | wc -l)
else
    # If it's not a directory, just pass through to eza
    FILE_COUNT=0
fi

# If file count exceeds threshold, use regular ls
if [ "$FILE_COUNT" -gt "$THRESHOLD" ]; then
    command ls "${ARGS[@]}"
else
    # Use eza with nice defaults
    eza --group-directories-first --header --icons=always --color=always --git "${ARGS[@]}"
fi

