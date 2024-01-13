{ pkgs, lib, config, ... }:

with lib;
let cfg = 
    config.modules.packages;
    screen = pkgs.writeShellScriptBin "screen" ''${builtins.readFile ../scripts/screen}'';
    bandw = pkgs.writeShellScriptBin "bandw" ''${builtins.readFile ../scripts/bandw}'';
    maintenance = pkgs.writeShellScriptBin "maintenance" ''${builtins.readFile ../scripts/maintenance}'';

in {
    options.modules.packages = { enable = mkEnableOption "packages"; };
    config = mkIf cfg.enable {
    	home.packages = with pkgs; [
            gnome.adwaita-icon-theme
            sudo
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
            screen 
            bandw 
            maintenance
            wf-recorder 
            slack
            telegram-desktop
            neofetch
            clamav
            libsForQt5.qt5.qtwayland
        ];
    };
}
