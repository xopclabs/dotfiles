{ config, lib, pkgs, inputs, ... }:

{
    imports = [
        inputs.sops-nix.homeManagerModules.sops
    ];

    # Let home-manager manage itself
    programs.home-manager.enable = true;

    # Sops for home-manager configuration
    sops = {
        defaultSopsFile = ../../secrets/shared/personal.yaml;
        age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
    };
} 
