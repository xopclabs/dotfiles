{ config, pkgs, inputs, ... }:

{
    programs.zsh.enable = true;
    # Set up user and enable sudo
    users.users.xopc = {
        extraGroups = [ "input" "wheel" "networkmanager" "storage" ];
        shell = pkgs.zsh;
        isNormalUser = true;
    };

    # Set up locales (timezone and keyboard layout)
    i18n.defaultLocale = "en_US.UTF-8";
    console = {
        font = "Lat2-Terminus16";
        keyMap = "us";
    };
    services.automatic-timezoned.enable = true;
}
