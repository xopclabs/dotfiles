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
        pam.services.swaylock = {};
        polkit.enable = true;
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
