 {config, pkgs, inputs, ... }:

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
        GTK_RC_FILES = "$HOME/.local/share/gtk-1.0/gtkrc";
        GTK2_RC_FILES = "$HOME/.local/share/gtk-2.0/gtkrc";
        MOZ_ENABLE_WAYLAND = "1";
        EDITOR = "nvim";
        TERM="xterm-kitty";
    };
    services.upower.enable = true;

    hardware = {
        opengl = {
            enable = true;
            driSupport = true;
        };
        nvidia = {
            modesetting.enable = true;
            powerManagement.enable = false;
            open = false;
            nvidiaSettings = false;
            package = config.boot.kernelPackages.nvidiaPackages.stable;
            prime = {
                reverseSync.enable = true;
                allowExternalGpu = false;
                intelBusId = "PCI:0:2:0";
                nvidiaBusId = "PCI:1:0:0";
            };
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

    # Do not touch
    system.stateVersion = "20.09";
    }
