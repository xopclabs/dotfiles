{ config, pkgs, inputs, ... }:

{
    # Security 
    security = {
        sudo = {
            enable = true;
            extraRules = [{
                commands = [
                    {
                        command = "${pkgs.systemd}/bin/systemctl suspend";
                        options = [ "NOPASSWD" ];
                    }
                    {
                        command = "${pkgs.systemd}/bin/reboot";
                        options = [ "NOPASSWD" ];
                    }
                    {
                        command = "${pkgs.systemd}/bin/poweroff";
                        options = [ "NOPASSWD" ];
                    }
                ];
                groups = [ "wheel" ];
            }];
        };
        # Extra security
        protectKernelImage = true;
        # Swaylock
        pam.services.hyprlock.text = "auth include login";
        polkit.enable = true;
    };
    services.clamav = {
        daemon.enable = false;
        updater.enable = false;
    };
    services.gnome.gnome-keyring.enable = true;

    sops = {
        defaultSopsFile = ../../secrets.yaml;
        age.sshKeyPaths = [ "/home/xopc/.ssh/id_ed25519" ];
    };
}
