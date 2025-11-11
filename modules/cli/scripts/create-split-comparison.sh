#!/usr/bin/env bash
set -euo pipefail

# --- parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --left) LEFT_SPEC="$2"; shift 2;;
    --left_name) LEFT_NAME="${2:-}"; shift 2;;
    --right) RIGHT_SPEC="$2"; shift 2;;
    --right_name) RIGHT_NAME="${2:-}"; shift 2;;
    --output) OUTPUT_DIR="$2"; shift 2;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

: "${LEFT_SPEC:?--left is required}"
: "${RIGHT_SPEC:?--right is required}"
: "${OUTPUT_DIR:?--output is required}"

mkdir -p "$OUTPUT_DIR"

# --- split spec into directory and pattern ---
split_spec() {
  local spec="$1"
  local dir="${spec%/*}"
  local pattern="${spec##*/}"
  echo "$dir" "$pattern"
}

read LEFT_DIR LEFT_PATTERN  <<<"$(split_spec "$LEFT_SPEC")"
read RIGHT_DIR RIGHT_PATTERN <<<"$(split_spec "$RIGHT_SPEC")"

# --- helper: strip suffix pattern from filename to get key ---
key_from_file() {
  local file="$1"
  local pattern="$2"
  local base="${file##*/}"
  local key="$base"
  key="${key%"${pattern#\*}"}"
  echo "$key"
}

# --- build maps ---
declare -A LEFT_MAP
declare -A RIGHT_MAP

shopt -s nullglob

for f in "$LEFT_DIR"/$LEFT_PATTERN; do
  key=$(key_from_file "$f" "$LEFT_PATTERN")
  LEFT_MAP["$key"]="$f"
done

for f in "$RIGHT_DIR"/$RIGHT_PATTERN; do
  key=$(key_from_file "$f" "$RIGHT_PATTERN")
  RIGHT_MAP["$key"]="$f"
done

# --- match and run ffmpeg ---
for key in "${!LEFT_MAP[@]}"; do
  left_file="${LEFT_MAP[$key]}"
  if [[ -n "${RIGHT_MAP[$key]:-}" ]]; then
    right_file="${RIGHT_MAP[$key]}"
    out_file="$OUTPUT_DIR/$key.mp4"

    echo ">> Processing key=$key"
    ffmpeg -y -i "$left_file" -i "$right_file" \
      -filter_complex '[0:v]crop=iw/2:ih:0:0[left];[1:v]eq=brightness=-0.1,crop=iw/2:ih:iw/2:0[right];[left][right]hstack=inputs=2,format=yuv420p[v]' \
      -map '[v]' -map '0:a?' -c:v libx264 -pix_fmt yuv420p -movflags +faststart -shortest "$out_file" -loglevel 'error'
  else
    echo "No match for LEFT $left_file (key=$key)" >&2
  fi
done
