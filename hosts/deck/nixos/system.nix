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
            experimental-features = nix-command flakes pipe-operators
            keep-outputs = true
            trusted-users = root xopc
        '';
    };
    nixpkgs.config.allowUnfree = true;

    boot = {
        tmp.cleanOnBoot = true;
        kernelPackages = pkgs.linuxPackages_latest;
        loader = {
            efi = {
                canTouchEfiVariables = true;
                efiSysMountPoint = "/boot";
            };

            grub = {
                enable = true;
                device = "nodev";
                efiSupport = true;
                enableCryptodisk = true;
            };

            systemd-boot = {
                enable = false;
                editor = false;
            };
            timeout = 2;
        };
    };

    services.udev.extraRules = ''
        # Steno stuff
        # Allow read/write to ttyACM0 serial port
        KERNEL=="ttyACM0", MODE="0666"
        # Allow uinput as non-root user (in input group)
        KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
        # Sweep keyboard plover-HID non-root access. 
        SUBSYSTEM=="hidraw", ATTRS{driver}=="hid-generic", MODE="0660", GROUP="input"

        # Fix washed out colors on HDMI with Intel graphics
        ACTION=="add", SUBSYSTEM=="module", KERNEL=="i915", RUN+="${pkgs.libdrm.bin}/bin/proptest -M i915 -D /dev/dri/card0 107 connector 103 1"
        ACTION=="add", SUBSYSTEM=="module", KERNEL=="i915", RUN+="${pkgs.libdrm.bin}/bin/proptest -M i915 -D /dev/dri/card1 107 connector 103 1"

        # Limit battery charge to 80%
        SUBSYSTEM=="power_supply", KERNEL=="BAT0", ACTION=="add", ATTR{charge_control_end_threshold}="80"
    '';

    hardware = {
        graphics = {
            enable = true;
        };
    };

    # NFS share client
    fileSystems."/mnt/nas" = {
        device = "192.168.254.11:/mnt/raid_pool/shared";
        fsType = "nfs";
        options = [ "x-systemd.automount" "noauto" ];
    };

    # Battery?
    services.upower.enable = true;
    # Automounting
    services.gvfs.enable = true;
    services.devmon.enable = true;
    services.udisks2.enable = true;

    # Hibernate
    powerManagement.enable = true;
    systemd.sleep.extraConfig = ''
        HibernateDelaySec=3h 
    '';
    
    # Ignore power button presses
    services.logind = {
        powerKey = "ignore";
	powerKeyLongPress = "poweroff";
    };

    # Docker support
    virtualisation.docker = {
        enable = true;
        enableOnBoot = true;
        rootless.enable = true;
    };

    # System env variables
    environment.variables = {
        NIXOS_CONFIG = "$HOME/dotfiles/hosts/deck/system/configuration.nix";
        NIXOS_CONFIG_DIR = "$HOME/dotfiles";
        NH_FLAKE = "$HOME/dotfiles";
        GTK_RC_FILES = "$HOME/.local/share/gtk-1.0/gtkrc";
        GTK2_RC_FILES = "$HOME/.local/share/gtk-2.0/gtkrc";
        MOZ_ENABLE_WAYLAND = "1";
        EDITOR = "nvim";
        TERM="xterm-kitty";
    };

    services.thermald.enable = true;
    services.power-profiles-daemon.enable = true;

    # Do not touch
    system.stateVersion = "24.11";
}
