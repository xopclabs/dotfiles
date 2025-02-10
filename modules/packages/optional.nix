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
            --add-flags "--ozone-platform=wayland --enable-features=UseOzonePlatform,WebRTCPipeWireCapturer"
            #--add-flags "--ozone-platform=wayland --enable-features=UseOzonePlatform,WebRTCPipeWireCapturer" \
            #--add-flags "--proxy-server='socks5://localhost:10808'" 
    '';
  });
in {
    options.modules.packages = { enable = mkEnableOption "packages"; };
    config = mkIf cfg.enable {
    	home.packages = with pkgs; [
            # gui/tui
            grim 
            slurp 
            imagemagick 
            ffmpeg
            wev
            wf-recorder 
            adwaita-icon-theme
            ranger
            slack
            telegram-desktop
            libsForQt5.qt5.qtwayland
            pavucontrol
            rnote
            chromium
            stremio
            moonlight-qt
            tigervnc
            steam
            # hiddify-app
            libreoffice
        ];
    };
}
