{ inputs, pkgs, lib, config, ... }:

with lib;
let
    cfg = config.modules.other.minecraft;

    # PrismLauncher-Cracked still references the removed Qt5 extra-cmake-modules alias.
    pkgsWithEcm = pkgs.extend (final: prev: {
        extra-cmake-modules = prev.kdePackages.extra-cmake-modules;
    });

    prismPkgs = pkgsWithEcm.extend inputs.prismlauncher.overlays.default;

    prismlauncher = prismPkgs.prismlauncher.override {
        prismlauncher-unwrapped = prismPkgs.prismlauncher-unwrapped.overrideAttrs (old: {
            nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.pkg-config ];
        });
        additionalPrograms = [ pkgs.ffmpeg ];
        jdks = [ pkgs.jdk8 pkgs.jdk17 pkgs.jdk21 pkgs.jdk25 ];
    };

    configurePrismLauncherStorage = pkgs.writeShellScript "configure-prismlauncher-storage" ''
        set -eu

        prism_data="$HOME/.local/share/PrismLauncher"
        cfg="$prism_data/prismlauncher.cfg"
        target_root="$HOME/games/prismlauncher"
        target_instances="$target_root/instances"
        legacy_instances="$prism_data/instances"

        mkdir -p "$prism_data" "$target_instances"

        if [ -L "$legacy_instances" ]; then
            current_target="$(${pkgs.coreutils}/bin/readlink "$legacy_instances")"
            if [ "$current_target" != "$target_instances" ]; then
                ${pkgs.coreutils}/bin/rm "$legacy_instances"
                ${pkgs.coreutils}/bin/ln -s "$target_instances" "$legacy_instances"
            fi
        elif [ -d "$legacy_instances" ]; then
            for path in "$legacy_instances"/* "$legacy_instances"/.[!.]* "$legacy_instances"/..?*; do
                [ -e "$path" ] || continue
                name="$(${pkgs.coreutils}/bin/basename "$path")"
                if [ -e "$target_instances/$name" ]; then
                    echo "PrismLauncher instance already exists in $target_instances: $name; leaving $path in place" >&2
                else
                    ${pkgs.coreutils}/bin/mv "$path" "$target_instances/"
                fi
            done

            if [ -z "$(${pkgs.findutils}/bin/find "$legacy_instances" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
                ${pkgs.coreutils}/bin/rmdir "$legacy_instances"
                ${pkgs.coreutils}/bin/ln -s "$target_instances" "$legacy_instances"
            else
                echo "PrismLauncher legacy instances remain in $legacy_instances due to name conflicts" >&2
            fi
        elif [ ! -e "$legacy_instances" ]; then
            ${pkgs.coreutils}/bin/ln -s "$target_instances" "$legacy_instances"
        else
            echo "PrismLauncher instances path exists but is not a directory or symlink: $legacy_instances" >&2
        fi

        tmp="$(${pkgs.coreutils}/bin/mktemp)"
        if [ -f "$cfg" ]; then
            ${pkgs.gawk}/bin/awk -v value="$target_instances" '
                BEGIN { done = 0; inGeneral = 0 }
                /^\[General\]$/ { print; inGeneral = 1; next }
                /^\[/ {
                    if (inGeneral && !done) {
                        print "InstanceDir=" value
                        done = 1
                    }
                    inGeneral = 0
                }
                inGeneral && /^InstanceDir=/ {
                    if (!done) {
                        print "InstanceDir=" value
                        done = 1
                    }
                    next
                }
                { print }
                END {
                    if (!done) {
                        if (!inGeneral) {
                            print "[General]"
                        }
                        print "InstanceDir=" value
                    }
                }
            ' "$cfg" > "$tmp"
        else
            printf '[General]\nInstanceDir=%s\n' "$target_instances" > "$tmp"
        fi
        ${pkgs.coreutils}/bin/mv "$tmp" "$cfg"
    '';
in {
    options.modules.other.minecraft = { enable = mkEnableOption "minecraft"; };
    config = mkIf cfg.enable {
        home.packages = [ prismlauncher ];

        home.activation.configurePrismLauncherStorage =
            lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                run ${configurePrismLauncherStorage}
            '';
    };
}
