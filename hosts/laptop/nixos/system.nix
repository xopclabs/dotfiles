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
        # Disable Nvidia dGPU
        extraModprobeConfig = ''
          blacklist nouveau
          options nouveau modeset=0
        '';
        blacklistedKernelModules = [ "nouveau" "nvidia" "nvidia_drm" "nvidia_modeset" ];
    };

    services.udev.extraRules = ''
        # Remove NVIDIA USB xHCI Host Controller devices, if present
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", ATTR{power/control}="auto", ATTR{remove}="1"
        # Remove NVIDIA USB Type-C UCSI devices, if present
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c8000", ATTR{power/control}="auto", ATTR{remove}="1"
        # Remove NVIDIA Audio devices, if present
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}="auto", ATTR{remove}="1"
        # Remove NVIDIA VGA/3D controller devices
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", ATTR{power/control}="auto", ATTR{remove}="1"

        # Steno stuff
        # Allow read/write to ttyACM0 serial port
        KERNEL=="ttyACM0", MODE="0666"
        # Allow uinput as non-root user (in input group)
        KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
        # Sweep keyboard plover-HID non-root access. 
        SUBSYSTEM=="hidraw", ATTRS{driver}=="hid-generic", MODE="0660", GROUP="input"

        # Prevent lid waking up from suspend
        ACTION=="add" SUBSYSTEM=="pci" ATTR{vendor}=="0x8086" ATTR{device}=="0x9d2f" ATTR{power/wakeup}="disabled"

        # Fix washed out colors on HDMI with Intel graphics
        ACTION=="add", SUBSYSTEM=="module", KERNEL=="i915", RUN+="${pkgs.libdrm.bin}/bin/proptest -M i915 -D /dev/dri/card0 107 connector 103 1"
        ACTION=="add", SUBSYSTEM=="module", KERNEL=="i915", RUN+="${pkgs.libdrm.bin}/bin/proptest -M i915 -D /dev/dri/card1 107 connector 103 1"

        # Limit battery charge to 80%
        SUBSYSTEM=="power_supply", KERNEL=="BAT0", ACTION=="add", ATTR{charge_control_end_threshold}="80"
    '';

    # Enable quicksync
    environment.sessionVariables = { LIBVA_DRIVER_NAME = "iHD"; }; # Force intel-media-driver
    hardware = {
        graphics = {
            enable = true;
            extraPackages = with pkgs; [
              intel-media-driver
              intel-vaapi-driver
              libdrm.bin
            ];
        };
    };

    # NFS share client
    fileSystems."/mnt/nas" = {
        device = "192.168.254.10:/mnt/raid_pool/shared";
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
        NIXOS_CONFIG = "$HOME/dotfiles/hosts/laptop/system/configuration.nix";
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
