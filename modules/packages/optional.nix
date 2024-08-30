{ pkgs, lib, config, inputs, ... }:

with lib;
let cfg = config.modules.packages;
    slack = pkgs.slack.overrideAttrs (old: {
    installPhase = old.installPhase + ''
        rm $out/bin/slack

        makeWrapper $out/lib/slack/slack $out/bin/slack \
            --prefix XDG_DATA_DIRS : $GSETTINGS_SCHEMAS_PATH \
            --prefix PATH : ${lib.makeBinPath [pkgs.xdg-utils]} \
            --add-flags "--ozone-platform=wayland --enable-features=UseOzonePlatform,WebRTCPipeWireCapturer" \
            --add-flags "--proxy-server='socks5://localhost:10808'" 
    '';
  });
in {
    options.modules.packages = { enable = mkEnableOption "packages"; };
    config = mkIf cfg.enable {
    	home.packages = with pkgs; [
            # zmk-nix
            inputs.zmk-nix.packages.${system}.firmware
            inputs.zmk-nix.packages.${system}.flash
            inputs.zmk-nix.packages.${system}.update
            # gui/tui
            grim 
            slurp 
            imagemagick 
            ffmpeg
            wev
            wf-recorder 
            gnome.adwaita-icon-theme
            ranger
            slack
            discord
            telegram-desktop
            libsForQt5.qt5.qtwayland
            pavucontrol
            rnote
            chromium
            stremio
            moonlight-qt
            tigervnc
            steam
        ];
    };
}
