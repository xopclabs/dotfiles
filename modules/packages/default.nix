{ pkgs, lib, config, inputs, ... }:

with lib;
let cfg = config.modules.packages;
    maintenance = pkgs.writeShellScriptBin "maintenance" ''${builtins.readFile ../scripts/maintenance}'';
    sftpmpv = pkgs.writeShellScriptBin "sftpmpv" ''${builtins.readFile ../scripts/sftpmpv}'';
    tm = pkgs.writeShellScriptBin "tm" ''${builtins.readFile ../scripts/tm}'';
in {
    options.modules.packages = { enable = mkEnableOption "packages"; };
    config = mkIf cfg.enable {
    	home.packages = with pkgs; [
            # scripts
            maintenance
            sftpmpv
            tm
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
        ];
    };
}
