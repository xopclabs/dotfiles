{ config, pkgs, inputs, ... }:

{
    # Security 
    security = {
        sudo = {
            enable = true;
            extraRules = [{
                commands = [
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
    services.clamav = {
        daemon.enable = false;
        updater.enable = false;
    };

    sops = {
        defaultSopsFile = ../../../secrets/shared/personal.yaml;
        age.sshKeyPaths = [ "/etc/ssh/id_ed25519" ];
    };

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
