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

in {
    options.modules.gui.easyeffects = { enable = mkEnableOption "easyeffects"; };
    config = mkIf cfg.enable {
        services.easyeffects.enable = true;

        home.activation.easyeffectsPatchRc =
            lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                run ${patchScript}
            '';
    };
}
