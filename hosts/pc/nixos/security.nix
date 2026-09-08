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
        age.sshKeyPaths = [ "/etc/ssh/id_ed25519" ];
    };
    fileSystems."/home".neededForBoot = true;

    # TPM2 support for LUKS PIN unlock on this host.
    # Enroll imperatively after rebuilding:
    #   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 --tpm2-with-pin=yes /dev/nvme0n1p2
    security.tpm2 = {
        enable = true;
        pkcs11.enable = true;
        tctiEnvironment.enable = true;
    };
    systemd.tpm2.enable = true;
    boot.initrd.systemd = {
        enable = true;
        tpm2.enable = true;
    };

}
