{ pkgs, lib, config, inputs, ... }:

with lib;
let cfg = config.modules.packages;
    screen = pkgs.writeShellScriptBin "screen" ''${builtins.readFile ../scripts/screen}'';
    bandw = pkgs.writeShellScriptBin "bandw" ''${builtins.readFile ../scripts/bandw}'';
    maintenance = pkgs.writeShellScriptBin "maintenance" ''${builtins.readFile ../scripts/maintenance}'';
    sftpmpv = pkgs.writeShellScriptBin "sftpmpv" ''${builtins.readFile ../scripts/sftpmpv}'';
    tm = pkgs.writeShellScriptBin "tm" ''${builtins.readFile ../scripts/tm}'';

in {
    options.modules.packages = { enable = mkEnableOption "packages"; };
    config = mkIf cfg.enable {
    	home.packages = with pkgs; [
            # scripts
            screen 
            bandw 
            maintenance
            sftpmpv
            tm
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
            mpv 
            pqiv
            wf-recorder 
            slack
            telegram-desktop
            neofetch
            afetch
            clamav
            pipes
            libsForQt5.qt5.qtwayland
        ];
    };
}
