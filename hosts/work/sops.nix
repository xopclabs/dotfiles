{ config, lib, inputs, ...}:

{
    sops = {
        defaultSopsFile = ../../secrets/shared/work.yaml;
        age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
    };
}
