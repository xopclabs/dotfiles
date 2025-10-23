{ config, pkgs, inputs, ... }:

{
    # Set up user and enable sudo
    sops.secrets.userpass = {
        sopsFile = ../../../secrets/hosts/${config.networking.hostName}.yaml;
        neededForUsers = true;
    };
    users.users.homelab = {
        extraGroups = [ "input" "wheel" "networkmanager" "storage" "adbusers" "docker" "tss" ];
        shell = pkgs.zsh;
        isNormalUser = true;
        hashedPasswordFile = config.sops.secrets.userpass.path;
    };
    programs.zsh.enable = true;

    # Set up user builder user
    users.users.nix-builder = {
        isNormalUser = true;
	openssh.authorizedKeys.keys = [
	    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAFmiLCnm7UOpY9Ak+gxJcsHXBZOfyWiFtl35c49CjjE"
        ];
    };
    nix.settings.trusted-users = [ "nix-builder" ];


    # Set up locales (timezone and keyboard layout)
    i18n.defaultLocale = "en_US.UTF-8";
    console = {
        font = "Lat2-Terminus16";
        keyMap = "us";
    };
    services.automatic-timezoned.enable = true;

    # Enable dynamically linked binaries to work
    programs.nix-ld.enable = true;
}
