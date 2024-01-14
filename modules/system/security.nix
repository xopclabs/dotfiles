{ config, pkgs, inputs, ... }:

{
    # Security 
    security = {
        sudo.enable = true;
        # Extra security
        protectKernelImage = true;
        # Swaylock
        pam.services.swaylock = {};
    };
    services.clamav = {
        daemon.enable = true;
        updater.enable = true;
    };
    services.gnome.gnome-keyring.enable = true;

    sops = {
        defaultSopsFile = ../../secrets.yaml;
        age.keyFile = "/home/xopc/.config/sops/age/keys.txt";
        age.sshKeyPaths = [ "/home/xopc/.ssh/id_ed25519" ];
    };
}
