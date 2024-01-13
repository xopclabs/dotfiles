{ config, pkgs, inputs, ... }:

{
    # Nix settings, auto cleanup and enable flakes
    nix = {
        settings.auto-optimise-store = true;
        settings.allowed-users = [ "xopc" ];
        gc = {
            automatic = true;
            dates = "weekly";
            options = "--delete-older-than 7d";
        };
        extraOptions = ''
            experimental-features = nix-command flakes
            keep-outputs = true
            keep-derivations = true
        '';
    };
    nixpkgs.config.allowUnfree = true;

    # Boot settings: clean /tmp/, latest kernel and enable bootloader
    boot = {
        tmp.cleanOnBoot = true;
        loader = {
            systemd-boot.enable = true;
            systemd-boot.editor = false;
            efi.canTouchEfiVariables = true;
            timeout = 2;
        };
    };

    environment.variables = {
        NIXOS_CONFIG = "$HOME/nix-config/nixos/configuration.nix";
        NIXOS_CONFIG_DIR = "$HOME/nix-config";
        EDITOR = "nvim";
        TERM="xterm-kitty";
    };
    services.upower.enable = true;

    hardware = {
        opengl = {
            enable = true;
            driSupport = true;
        };
    };

    # Do not touch
    system.stateVersion = "20.09";
}
