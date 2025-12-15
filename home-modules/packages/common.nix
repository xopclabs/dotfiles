{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.packages.common;

in {
    options.modules.packages.common = { enable = mkEnableOption "common"; };
    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            # dev-tools
            cmake
            mesa
            pkg-config
            git 
            lua 
            zig 
            # linux utils
            util-linux
            iputils
            usbutils
            pciutils
            coreutils-full
            dig
            ps
            brightnessctl
            ripgrep
            tealdeer
            htop 
            pass 
            gnupg 
            zip
            unzip 
	    _7zz
            lm_sensors
            lowdown 
            zk
            slop
            age 
            libnotify
            pqiv
            neofetch
            #clamav
            pipes
            tio
            melt
            pfetch
            sops
            devenv
            dust duf
            ncdu
        ];
    };
}
