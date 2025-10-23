{ config, pkgs, inputs, ... }:

{
    nix = {
        buildMachines = [{
            hostName = "homelab-builder";
            system = "x86_64-linux";
            protocol = "ssh-ng";
            maxJobs = 4;
            speedFactor = 2;
            supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
        }];
        distributedBuilds = true;
        settings.builders-use-substitutes = false;
    };
    
    sops.secrets."ssh-builder/id_ed25519".path = "/root/.ssh/nix-builder";
    sops.secrets."ssh-builder/id_ed25519.pub".path = "/root/.ssh/nix-builder.pub";
    sops.secrets."ssh-builder/config".path = "/root/.ssh/hosts_config";
    programs.ssh = {
        extraConfig = ''
            Include /root/.ssh/hosts_config
        '';
    };
}