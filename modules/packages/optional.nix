{ pkgs, lib, config, inputs, ... }:

with lib;
let cfg = config.modules.packages.optional;
    slack = pkgs.slack.overrideAttrs (old: {
    installPhase = old.installPhase + ''
        rm $out/bin/slack

        makeWrapper $out/lib/slack/slack $out/bin/slack \
            --prefix XDG_DATA_DIRS : $GSETTINGS_SCHEMAS_PATH \
            --prefix PATH : ${lib.makeBinPath [pkgs.xdg-utils]} \
            --add-flags "--ozone-platform=wayland --enable-features=UseOzonePlatform,WebRTCPipeWireCapturer" 
    '';
  });
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
            pkgs.libsForQt5.qt5.qtwayland
            pkgs.pavucontrol
            pkgs.moonlight-qt
            pkgs.tigervnc
            pkgs.libreoffice
            pkgs.python3
            pkgs.zoom-us
            pkgs.zotero
	        pkgs.transmission_4-gtk
        ];
    };
}
