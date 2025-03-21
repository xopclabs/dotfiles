{ pkgs, lib, config, inputs, ... }:

{
    home.packages = with pkgs; [
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
	ps
        brightnessctl
        ripgrep
        tealdeer
        eza 
        htop 
        fzf
        pass 
        gnupg 
        bat
        zip
        unzip 
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
    ];
}
