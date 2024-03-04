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
    maintenance = pkgs.writeShellScriptBin "maintenance" ''${builtins.readFile ../scripts/maintenance}'';
    sftpmpv = pkgs.writeShellScriptBin "sftpmpv" ''${builtins.readFile ../scripts/sftpmpv}'';
    tm = pkgs.writeShellScriptBin "tm" ''${builtins.readFile ../scripts/tm}'';
    freshman_start = pkgs.writeShellScriptBin "freshman_start" ''${builtins.readFile ../scripts/freshman_start}'';
in {
    options.modules.packages = { enable = mkEnableOption "packages"; };
    config = mkIf cfg.enable {
    	home.packages = with pkgs; [
            # scripts
            maintenance
            sftpmpv
            tm
            freshman_start
            # zmk-nix
            inputs.zmk-nix.packages.${system}.firmware
            inputs.zmk-nix.packages.${system}.flash
            inputs.zmk-nix.packages.${system}.update
            # other
            utillinux
            iputils
            usbutils
            pciutils
            busybox
            brightnessctl
            sudo
            gnome.adwaita-icon-theme
            ripgrep
            ffmpeg
            tealdeer
            eza 
            ranger
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
            git 
            python3 
            lua 
            zig 
            pqiv
            wf-recorder 
            slack
            discord
            telegram-desktop
            neofetch
            afetch
            clamav
            pipes
            libsForQt5.qt5.qtwayland
            wev
            pavucontrol
            rnote
            tio
            chromium
            stremio
        ];
    };
}
