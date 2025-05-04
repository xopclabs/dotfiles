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

    sops.secrets."ssh-laptop/id_ed25519" = {
        path = "/home/homelab/.ssh/id_ed25519_laptop";
	owner = config.users.users.homelab.name;
    };
    sops.secrets."ssh-laptop/id_ed25519.pub" = {
        path = "/home/homelab/.ssh/id_ed25519_laptop.pub";
	owner = config.users.users.homelab.name;
    };
    sops = {
        defaultSopsFile = ../secrets.yaml;
        age.sshKeyPaths = [ "/home/homelab/.ssh/id_ed25519" config.sops.secrets."ssh-laptop/id_ed25519".path ];
        age.keyFile = "/home/homelab/.config/sops/age/keys.txt";
    };
}
