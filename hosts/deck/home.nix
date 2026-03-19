{ config, lib, pkgs, inputs, ... }:

{
    # Let home-manager manage itself
    programs.home-manager.enable = true;

    # Sops for home-manager configuration
    sops = {
        defaultSopsFile = ../../secrets/shared/personal.yaml;
        age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
    };
} 
