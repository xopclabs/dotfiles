{ config, pkgs, inputs, ... }:

{
    nix = {
        # Ryzen 9 3900X: 12c/24t, 48GB. Two slots for the same host (x86_64 +
        # i686 via extra-platforms). Match the daemon (2 jobs × 12 cores).
        # speedFactor vs the Deck (~4c): send big-parallel (kernel) here.
        buildMachines = [
            {
                hostName = "homelab-builder";
                system = "x86_64-linux";
                protocol = "ssh-ng";
                maxJobs = 2;
                speedFactor = 8;
                supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
            }
            {
                hostName = "homelab-builder";
                system = "i686-linux";
                protocol = "ssh-ng";
                maxJobs = 2;
                speedFactor = 8;
                supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
            }
        ];
        distributedBuilds = true;
        settings.builders-use-substitutes = true;
    };
    
    sops.secrets."ssh-builder/id_ed25519".path = "/root/.ssh/homelab-builder";
    sops.secrets."ssh-builder/id_ed25519.pub".path = "/root/.ssh/homelab-builder.pub";
    sops.secrets."ssh-builder/config".path = "/root/.ssh/hosts_config";
    programs.ssh = {
        extraConfig = ''
            Include /root/.ssh/hosts_config
        '';
    };
}