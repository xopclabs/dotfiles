{ config, pkgs, inputs, ... }:

{
    programs.zsh.enable = true;
    programs.direnv.enable = true;
    programs.adb.enable = true;

    # Set up user and enable sudo
    sops.secrets.userpass.neededForUsers = true;
    users.users.xopc = {
        extraGroups = [ "input" "wheel" "networkmanager" "storage" "adbusers" "docker" "tss" ];
        shell = pkgs.zsh;
        isNormalUser = true;
        hashedPasswordFile = config.sops.secrets.userpass.path;
    };

    # Set up locales (timezone and keyboard layout)
    i18n.defaultLocale = "en_US.UTF-8";
    console = {
        font = "Lat2-Terminus16";
        keyMap = "us";
    };
    services.automatic-timezoned.enable = true;
}
