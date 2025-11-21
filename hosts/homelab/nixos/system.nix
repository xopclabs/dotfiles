{ config, pkgs, inputs, lib, modulesPath, ... }:

{
    imports = [
        (modulesPath + "/installer/scan/not-detected.nix")
    ];

    # Nix settings, auto cleanup and enable flakes
    nix = {
        settings.auto-optimise-store = true;
        settings.allowed-users = [ config.metadata.user ];
        settings.trusted-users = [ "root" config.metadata.user ];
        gc = {
            automatic = true;
            dates = "weekly";
            options = "--delete-older-than 7d";
        };
        extraOptions = ''
            experimental-features = nix-command flakes pipe-operators
            keep-outputs = true
        '';
    };
    nixpkgs.config.allowUnfree = true;
    environment.defaultPackages = [ pkgs.sudo pkgs.vim ];
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
		        device = "nodev";
                efiSupport = true;
                efiInstallAsRemovable = true;
            };
            timeout = 2;
        };
    };

    # NFS share client
    fileSystems = {
        "/mnt/nas" = {
            device = "192.168.254.11:/mnt/raid_pool/shared";
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
        daemon.settings = {
            dns = lib.mkIf config.homelab.pihole_unbound.enable [ config.metadata.network.ipv4 "1.1.1.1" ];
        };
    };
    virtualisation.oci-containers.backend = "docker";

    # System env variables
    environment.variables = {
        NIXOS_CONFIG = "$HOME/dotfiles/hosts/${config.metadata.hostName}/nixos/configuration.nix";
        NIXOS_CONFIG_DIR = "$HOME/dotfiles";
        NH_FLAKE = "$HOME/dotfiles";
        EDITOR = "nvim";
    };

    # Do not touch
    system.stateVersion = "24.11";
}
