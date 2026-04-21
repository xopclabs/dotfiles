{ pkgs, lib, config, ... }:

with lib;
let
    cfg = config.modules.gui.easyeffects;

    # Ensure [EffectsPipelines]/processAllInputs=false in easyeffectsrc.
    # Without this, EasyEffects v8 auto-moves every recording stream through
    # its virtual source. 
    patchScript = pkgs.writeShellScript "easyeffects-patch-rc" ''
        set -euo pipefail
        rc="''${XDG_CONFIG_HOME:-$HOME/.config}/easyeffects/db/easyeffectsrc"
        mkdir -p "$(dirname "$rc")"
        [ -f "$rc" ] || : > "$rc"
        tmp="$rc.hm-tmp.$$"
        ${pkgs.gawk}/bin/awk '
            BEGIN { handled = 0; section = "" }
            /^\[.*\]$/ {
                if (section == "[EffectsPipelines]" && !handled) {
                    print "processAllInputs=false"
                    handled = 1
                }
                section = $0
                print
                next
            }
            {
                if (section == "[EffectsPipelines]" && $0 ~ /^processAllInputs=/) {
                    print "processAllInputs=false"
                    handled = 1
                    next
                }
                print
            }
            END {
                if (section == "[EffectsPipelines]" && !handled) {
                    print "processAllInputs=false"
                    handled = 1
                }
                if (!handled) {
                    print ""
                    print "[EffectsPipelines]"
                    print "processAllInputs=false"
                }
            }
        ' "$rc" > "$tmp"
        if ! ${pkgs.diffutils}/bin/cmp -s "$rc" "$tmp"; then
            mv "$tmp" "$rc"
        else
            rm -f "$tmp"
        fi
    '';

    # Re-apply the preset after activations 
    loadLastPresetScript = pkgs.writeShellScript "easyeffects-load-last-preset" ''
        set -euo pipefail
        rc="''${XDG_CONFIG_HOME:-$HOME/.config}/easyeffects/db/easyeffectsrc"
        [ -f "$rc" ] || exit 0
        preset=$(${pkgs.gawk}/bin/awk '
            /^\[.*\]$/ { in_sec = ($0 == "[Presets]"); next }
            in_sec && /^lastLoadedOutputPreset=/ {
                sub(/^lastLoadedOutputPreset=/, "")
                print
                exit
            }
        ' "$rc")
        [ -n "$preset" ] || exit 0
        # Wait briefly for the daemon to be up. The wrapped binary's comm is
        # '.easyeffects-wr' (truncated at 15 chars) so exact -x won't match;
        # use substring match against comm and command line. Give up silently
        # after ~5s so we never fail activation.
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            if ${pkgs.procps}/bin/pgrep -f 'easyeffects' >/dev/null 2>&1; then
                break
            fi
            sleep 0.5
        done
        ${pkgs.easyeffects}/bin/easyeffects -l "$preset" >/dev/null 2>&1 || true
    '';

in {
    options.modules.gui.easyeffects = { enable = mkEnableOption "easyeffects"; };
    config = mkIf cfg.enable {
        services.easyeffects.enable = true;

        home.activation.easyeffectsPatchRc =
            lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                run ${patchScript}
            '';

        home.activation.easyeffectsLoadLastPreset =
            lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
                run ${loadLastPresetScript}
            '';
    };
}
