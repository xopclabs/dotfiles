{ config, pkgs, inputs, ... }:

{
    programs.zsh.enable = true;
    # Set up user and enable sudo
    users.users.xopc = {
        extraGroups = [ "input" "wheel" "networkmanager" ];
        shell = pkgs.zsh;
        isNormalUser = true;
    };

    # Set up locales (timezone and keyboard layout)
    time.timeZone = "Asia/Tbilisi";
    i18n.defaultLocale = "en_US.UTF-8";
    console = {
        font = "Lat2-Terminus16";
        keyMap = "us";
    };
}
