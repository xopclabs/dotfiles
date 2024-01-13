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
}
