{ config, pkgs, inputs, ... }:

{
    programs.zsh.enable = true;
    programs.direnv.enable = true;

    # Set up user and enable sudo
    sops.secrets.userpass = {
        sopsFile = ../../../secrets/hosts/${config.networking.hostName}.yaml;
        neededForUsers = true;
    };
    users.users.${config.metadata.user} = {
        extraGroups = [ "input" "wheel" "networkmanager" "storage" "adbusers" "docker" "tss" ];
        shell = pkgs.zsh;
        isNormalUser = true;
        hashedPasswordFile = config.sops.secrets.userpass.path;
    };

    # Set correct ownership for games and steam directories
    systemd.tmpfiles.rules = [
        "d /home/${config.metadata.user}/games 0755 ${config.metadata.user} users -"
    ];

    # Set up locales (timezone and keyboard layout)
    i18n.defaultLocale = "en_US.UTF-8";
    console = {
        font = "Lat2-Terminus16";
        keyMap = "us";
    };
    services.automatic-timezoned.enable = false;
    sops.secrets.timezone = {
        sopsFile = ../../../secrets/hosts/${config.networking.hostName}.yaml;
    };
    systemd.services.set-timezone = {
        description = "Set timezone from encrypted secret";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
        };
        script = ''
            TIMEZONE=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.timezone.path})
            ${pkgs.systemd}/bin/timedatectl set-timezone "$TIMEZONE"
        '';
    };

    programs.nix-ld.enable = true;
}
