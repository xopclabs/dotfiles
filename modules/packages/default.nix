{ pkgs, lib, config, inputs, ... }:

with lib;
let cfg = config.modules.packages;
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
    options.modules.packages = { enable = mkEnableOption "packages"; };
    config = mkIf cfg.enable {
    	home.packages = with pkgs; [
            # zmk-nix
            inputs.zmk-nix.packages.${system}.firmware
            inputs.zmk-nix.packages.${system}.flash
            inputs.zmk-nix.packages.${system}.update
            # dev-tools
            cmake
            mesa
            pkg-config
            git 
            python3 
            lua 
            zig 
            # linux utils
            utillinux
            iputils
            usbutils
            pciutils
            busybox
            brightnessctl
            sudo
            ripgrep
            ffmpeg
            tealdeer
            eza 
            htop 
            fzf
            pass 
            gnupg 
            bat
            unzip 
            lm_sensors
            lowdown 
            zk
            grim 
            slurp 
            slop
            imagemagick 
            age 
            libnotify
            pqiv
            wf-recorder 
            neofetch
            clamav
            pipes
            tio
            wev
            melt
            pfetch
            # gui/tui
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
        ];
    };
}
