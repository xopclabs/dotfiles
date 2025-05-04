{ config, pkgs, inputs, ... }:

{
    # Set up user and enable sudo
    users.users.homelab = {
        extraGroups = [ "input" "wheel" "networkmanager" "storage" "adbusers" "docker" "tss" ];
        shell = pkgs.zsh;
        isNormalUser = true;
    };
    programs.zsh.enable = true;

    # Set up locales (timezone and keyboard layout)
    i18n.defaultLocale = "en_US.UTF-8";
    console = {
        font = "Lat2-Terminus16";
        keyMap = "us";
    };
    services.automatic-timezoned.enable = true;
}
