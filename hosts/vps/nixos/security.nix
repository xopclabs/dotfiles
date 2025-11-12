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
        protectKernelImage = false;
    };
    services.gnome.gnome-keyring.enable = true;

    sops = {
        defaultSopsFile = ../../../secrets/shared/personal.yaml;
        age.sshKeyPaths = [ "/etc/ssh/id_ed25519" ];
    };
}
