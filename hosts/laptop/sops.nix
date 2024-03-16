{ config, lib, inputs, ...}:

{
    imports = [
        inputs.sops-nix.homeManagerModules.sops
    ];
    sops = {
        defaultSopsFile = ./secrets.yaml;
        age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
    };
}
