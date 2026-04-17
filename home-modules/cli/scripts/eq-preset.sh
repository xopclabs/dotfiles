#!/usr/bin/env bash

set -euo pipefail

preset_dir="${XDG_DATA_HOME:-$HOME/.local/share}/easyeffects/output"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/eq-preset"
state_file="$state_dir/state"

# Pinned presets with fixed positions in the tofi picker:
#   - 'Default' (second-to-last): dynamically regenerated on load; inherits the
#     plugin chain and input-gain of the last-used real preset with all EQ band
#     gains zeroed, so it is spectrally flat but loudness-matched.
#   - 'Off' (last): permanently empty plugin chain — truly no processing at all.
default_name='Default'
off_name='Off'

# Template for a preset with no processing. Used when auto-creating Off.json
# and Default.json on a fresh machine where they don't exist yet.
empty_preset_json='{
    "output": {
        "blocklist": [],
        "plugins_order": []
    }
}'

get_available_presets() {
    if [[ -d "$preset_dir" ]]; then
        find "$preset_dir" -maxdepth 1 -type f -name '*.json' -printf '%f\n' 2>/dev/null \
            | sed 's/\.json$//' \
            | sort
    fi
}

# Auto-create the pinned presets if missing, so the script works out of the box
# on a fresh machine. Both are bootstrapped as empty chains; 'Default' will be
# overwritten on first dynamic load anyway.
ensure_pinned_presets() {
    mkdir -p "$preset_dir"
    local name
    for name in "$default_name" "$off_name"; do
        local file="$preset_dir/$name.json"
        if [[ ! -f "$file" ]]; then
            echo "$empty_preset_json" > "$file"
        fi
    done
}

usage() {
    echo "Usage: eq-preset [preset_name]"
    echo ""
    echo "Loads an EasyEffects output preset and records usage."
    echo "If no preset_name is specified, shows a tofi picker ordered as:"
    echo "  - real presets first, sorted by usage frequency (desc)"
    echo "  - '$default_name' second-to-last (dynamic, loudness-matched)"
    echo "  - '$off_name' last (empty chain, bypasses all processing)"
    echo ""
    echo "'$default_name' is regenerated on every load: it inherits the plugin"
    echo "chain of the last real preset used, with all EQ band gains zeroed,"
    echo "so the spectral response is flat while the input-gain is preserved"
    echo "(no volume jump when switching between an EQ'd preset and flat)."
    echo ""
    echo "'$off_name' is never regenerated and represents 'no processing'."
    echo ""
    echo "Available presets:"
    while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        echo "  - $p"
    done < <(get_available_presets)
}

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a 'EasyEffects' "$@" 2>/dev/null || true
    fi
}

declare -A counts=()
last_effective=''

load_state() {
    [[ -f "$state_file" ]] || return 0
    local key value
    while IFS='=' read -r key value; do
        [[ -z "$key" ]] && continue
        case "$key" in
            __last_effective) last_effective="$value" ;;
            __last)           : ;; # legacy key, ignored
            *)                counts["$key"]="$value" ;;
        esac
    done < "$state_file"
}

save_state() {
    mkdir -p "$state_dir"
    {
        echo "__last_effective=$last_effective"
        for k in "${!counts[@]}"; do
            echo "$k=${counts[$k]}"
        done
    } > "$state_file"
}

# Returns 0 if $1 is a pinned preset (Default or Off), 1 otherwise.
is_pinned() {
    [[ "$1" == "$default_name" || "$1" == "$off_name" ]]
}

record_use() {
    local name="$1"
    counts["$name"]=$(( ${counts["$name"]:-0} + 1 ))
    # Only real presets update __last_effective; the pinned ones are skipped so
    # the dynamic 'Default' always inherits gain from the last real preset and
    # never from itself or from 'Off' (which has no processing at all).
    if ! is_pinned "$name"; then
        last_effective="$name"
    fi
    save_state
}

# Build tofi entries:
#   - all real (non-pinned) presets, sorted by usage count desc, name asc
#   - then '$default_name' (second-to-last)
#   - then '$off_name' (last)
build_ordered_list() {
    local available="$1"

    local pool
    pool=$(echo "$available" \
        | { grep -Fvx "$default_name" || true; } \
        | { grep -Fvx "$off_name" || true; })

    local sorted=''
    if [[ -n "$pool" ]]; then
        sorted=$(while IFS= read -r name; do
            [[ -z "$name" ]] && continue
            printf '%d\t%s\n' "${counts["$name"]:-0}" "$name"
        done <<< "$pool" | sort -k1,1nr -k2,2 | cut -f2-)
    fi

    [[ -n "$sorted" ]] && echo "$sorted"
    grep -Fxq "$default_name" <<< "$available" && echo "$default_name"
    grep -Fxq "$off_name"     <<< "$available" && echo "$off_name"
    return 0
}

# Regenerate the dynamic Default preset from <source_name>:
#   - copy the entire preset JSON
#   - for every plugin in plugins_order that has left/right band maps, set
#     every band's .gain to 0 (flat spectral response)
#   - input-gain and all other plugin params are preserved unchanged,
#     so the source preset's attenuation is applied without EQ coloring.
generate_dynamic_default() {
    local source_name="$1"
    local source_file="$preset_dir/$source_name.json"
    local target_file="$preset_dir/$default_name.json"
    local tmp_file="$target_file.tmp.$$"

    if [[ ! -f "$source_file" ]]; then
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        echo "warning: jq not found, skipping dynamic default regeneration" >&2
        return 1
    fi

    jq '
        (.output.plugins_order // []) as $order
        | reduce $order[] as $p (
            .;
            if (.output[$p] | type) == "object" and (.output[$p] | has("left")) then
                .output[$p].left |= with_entries(
                    if (.value | type) == "object" and (.value | has("gain"))
                    then .value.gain = 0
                    else . end
                )
                | .output[$p].right |= with_entries(
                    if (.value | type) == "object" and (.value | has("gain"))
                    then .value.gain = 0
                    else . end
                )
            else . end
        )
    ' "$source_file" > "$tmp_file" && mv "$tmp_file" "$target_file"
}

ensure_pinned_presets

if [[ "${1:-}" == '-h' ]] || [[ "${1:-}" == '--help' ]]; then
    usage
    exit 0
fi

load_state

available_presets=$(get_available_presets)
if [[ -z "$available_presets" ]]; then
    msg="No presets found in $preset_dir (even after ensuring pinned presets)."
    echo "$msg"
    notify 'No presets' "$msg"
    exit 1
fi

if [[ $# -gt 0 && -n "$1" ]]; then
    preset="$1"
    if ! grep -Fxq "$preset" <<< "$available_presets"; then
        echo "Error: Preset '$preset' not found"
        echo ''
        echo 'Available presets:'
        while IFS= read -r p; do
            [[ -z "$p" ]] && continue
            echo "  - $p"
        done <<< "$available_presets"
        exit 1
    fi
else
    ordered=$(build_ordered_list "$available_presets")
    preset=$(echo "$ordered" | tofi --prompt-text='EQ: ') || exit 0
fi

if [[ -z "$preset" ]]; then
    exit 0
fi

# If the user picked the dynamic default and we know a previous real preset,
# regenerate Default.json to inherit its input-gain with a flat EQ curve
# before asking EasyEffects to (re)load it.
if [[ "$preset" == "$default_name" ]] \
        && [[ -n "$last_effective" ]] \
        && [[ -f "$preset_dir/$last_effective.json" ]]; then
    if generate_dynamic_default "$last_effective"; then
        echo "↻ Regenerated '$default_name' from '$last_effective' (flat, gain-matched)"
    fi
fi

easyeffects -l "$preset"
record_use "$preset"
echo "✓ Loaded: $preset"
notify 'Preset loaded' "$preset"
