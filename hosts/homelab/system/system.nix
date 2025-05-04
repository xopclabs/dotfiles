{ config, pkgs, inputs, lib, modulesPath, ... }:

{
    imports = [
        (modulesPath + "/installer/scan/not-detected.nix")
    ];

    # Nix settings, auto cleanup and enable flakes
    nix = {
        settings.auto-optimise-store = true;
        settings.allowed-users = [ "homelab" ];
        gc = {
            automatic = true;
            dates = "weekly";
            options = "--delete-older-than 7d";
        };
        extraOptions = ''
            experimental-features = nix-command flakes
            keep-outputs = true
            trusted-users = root homelab
        '';
    };
    nixpkgs.config.allowUnfree = true;
    environment.defaultPackages = [ pkgs.sudo ];
    environment.systemPackages = map lib.lowPrio [
        pkgs.curl
        pkgs.gitMinimal
    ];

    boot = {
        tmp.cleanOnBoot = true;
        kernelPackages = pkgs.linuxPackages_latest;
        loader = {
            grub = {
                enable = true;
                efiSupport = true;
                efiInstallAsRemovable = true;
            };
            timeout = 2;
        };
    };
    
    # Enable SSH access for nixos-anywhere
    services.openssh.enable = true;
        users.users.root.openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA/qy9bDzKgpuIyHMalEPhMFgJ9hamF2LhR0kfk+2Et7"
    ];

    # NFS share client
    fileSystems = {
        "/mnt/nas" = {
            device = "192.168.254.11:/mnt/raid_pool/shared";
            fsType = "nfs";
            options = [ "x-systemd.automount" "noauto" ];
        };
        "/mnt/nas-containers" = {
            device = "192.168.254.11:/mnt/raid_pool/vm-containers";
            fsType = "nfs";
            options = [ "x-systemd.automount" "noauto" ];
        };
    };

    # Automounting
    services.gvfs.enable = true;
    services.devmon.enable = true;
    services.udisks2.enable = true;

    # Docker support
    virtualisation.docker = {
        enable = true;
        enableOnBoot = true;
        rootless.enable = true;
    };

    # System env variables
    environment.variables = {
        NIXOS_CONFIG = "$HOME/dotfiles/hosts/homelab/system/configuration.nix";
        NIXOS_CONFIG_DIR = "$HOME/dotfiles";
        NH_FLAKE = "$HOME/dotfiles";
        EDITOR = "nvim";
    };

    # Do not touch
    system.stateVersion = "24.11";
}
