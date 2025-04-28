{ pkgs, lib, config, inputs, ... }:

with lib;
let cfg = config.modules.packages;
    slack = pkgs.slack.overrideAttrs (old: {
    installPhase = old.installPhase + ''
        rm $out/bin/slack

        makeWrapper $out/lib/slack/slack $out/bin/slack \
            --argv0 ${pkgs.proxychains}/bin/proxychains4 \
            --prefix XDG_DATA_DIRS : $GSETTINGS_SCHEMAS_PATH \
            --prefix PATH : ${lib.makeBinPath [pkgs.xdg-utils]} \
            --add-flags "--ozone-platform=wayland --enable-features=UseOzonePlatform,WebRTCPipeWireCapturer" \
            --append-flags "--proxy-server='socks5://localhost:10808'" 
    '';
  });
in {
    options.modules.packages = { enable = mkEnableOption "packages"; };
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
            pkgs.libsForQt5.qt5.qtwayland
            pkgs.pavucontrol
            pkgs.rnote
            pkgs.chromium
            pkgs.stremio
            pkgs.moonlight-qt
            pkgs.tigervnc
            pkgs.libreoffice
            pkgs.vlc
            pkgs.python3
            pkgs.blender
        ];
    };
}
