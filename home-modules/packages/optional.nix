{ pkgs, lib, config, inputs, ... }:

with lib;
let cfg = config.modules.packages.optional;
    stablePkgs = import inputs.nixpkgs-stable {
        inherit (pkgs) system;
        config.allowUnfree = true;
    };
    slack = pkgs.slack.overrideAttrs (old: {
    installPhase = old.installPhase + ''
        rm $out/bin/slack

        makeWrapper $out/lib/slack/slack $out/bin/slack \
            --prefix XDG_DATA_DIRS : $GSETTINGS_SCHEMAS_PATH \
            --prefix PATH : ${lib.makeBinPath [pkgs.xdg-utils]} \
            --add-flags "--ozone-platform=wayland --enable-features=UseOzonePlatform,WebRTCPipeWireCapturer" 
    '';
  });

    # Zoom rewrites zoomus.conf on exit; pin native Wayland before every launch.
    ensureZoomWayland = pkgs.writeShellScript "ensure-zoom-wayland" ''
        set -euo pipefail
        conf="''${XDG_CONFIG_HOME:-$HOME/.config}/zoomus.conf"
        mkdir -p "$(dirname "$conf")"
        [ -f "$conf" ] || printf '%s\n' '[General]' > "$conf"
        tmp="$conf.hm-tmp.$$"
        ${pkgs.gawk}/bin/awk '
            BEGIN { xw = 0; ews = 0; section = "" }
            /^\[.*\]$/ {
                if (section == "[General]") {
                    if (!xw) print "xwayland=false"
                    if (!ews) print "enableWaylandShare=true"
                }
                section = $0
                print
                next
            }
            {
                if (section == "[General]" && $0 ~ /^xwayland=/) {
                    print "xwayland=false"
                    xw = 1
                    next
                }
                if (section == "[General]" && $0 ~ /^enableWaylandShare=/) {
                    print "enableWaylandShare=true"
                    ews = 1
                    next
                }
                print
            }
            END {
                if (section == "[General]") {
                    if (!xw) print "xwayland=false"
                    if (!ews) print "enableWaylandShare=true"
                } else if (!xw || !ews) {
                    print ""
                    print "[General]"
                    if (!xw) print "xwayland=false"
                    if (!ews) print "enableWaylandShare=true"
                }
            }
        ' "$conf" > "$tmp"
        if ! ${pkgs.diffutils}/bin/cmp -s "$conf" "$tmp"; then
            mv "$tmp" "$conf"
        else
            rm -f "$tmp"
        fi
    '';

    zoom-us = pkgs.symlinkJoin {
        name = "zoom-us-wayland";
        paths = [ pkgs.zoom-us ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
            wrapProgram $out/bin/zoom --run ${ensureZoomWayland}
            wrapProgram $out/bin/zoom-us --run ${ensureZoomWayland}
        '';
    };
in {
    options.modules.packages.optional = { enable = mkEnableOption "optional"; };
    config = mkIf cfg.enable {
    	home.packages = [
            # gui/tui
            slack
            pkgs.grim 
            pkgs.slurp 
            pkgs.imagemagick 
            pkgs.ffmpeg
            pkgs.wev
            pkgs.wf-recorder 
            pkgs.adwaita-icon-theme
            pkgs.telegram-desktop
            pkgs.pavucontrol
            pkgs.moonlight-qt
            pkgs.tigervnc
            stablePkgs.libreoffice
            pkgs.python3
            zoom-us
            pkgs.zotero
	        pkgs.transmission_4-gtk
            pkgs.android-tools
            pkgs.feishin
            pkgs.rclone
            pkgs.stremio-linux-shell
            pkgs.kew
        ];

        home.activation.zoomWaylandConf =
            lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                run ${ensureZoomWayland}
            '';
    };
}
