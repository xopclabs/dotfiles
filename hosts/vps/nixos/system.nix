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
            grub.enable = true;
            timeout = 2;
        };
    };

    # Docker support
    virtualisation.docker = {
        enable = true;
        enableOnBoot = true;
        rootless.enable = true;
    };

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
