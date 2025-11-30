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
        defaultSopsFile = ../../../secrets/shared/personal.yaml;
        age.sshKeyPaths = [ "/home/xopc/.ssh/id_ed25519" ];
        age.keyFile = "/var/lib/sops/age/keys.txt";
    };
    fileSystems."/home".neededForBoot = true;

    # Enable TPM2 to auto-unlock LUKS
    # NOTE: apparently my laptop doesn't support TPM2, so I've set every enable to false
    # should work though for any new machine I spin up, so leaving it here
    security.tpm2 = {
        enable = false;
        pkcs11.enable = true;
        tctiEnvironment.enable = true;
    };
    systemd.tpm2.enable = false;
    boot.initrd.systemd = {
        enable = false;
        tpm2.enable = false;
    };

}
