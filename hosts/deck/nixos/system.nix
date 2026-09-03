{ config, pkgs, inputs, lib, ... }:

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

        # Hibernation: resume from btrfs swapfile
        resumeDevice = "/dev/disk/by-partlabel/disk-primary-root";
        kernelParams = [ "resume_offset=533760" ];
    };

    # Disable zram since prevents hibernation since it's RAM-based
    zramSwap.enable = false;

    services.udev.extraRules = ''
        # Steno stuff
        # Allow read/write to ttyACM0 serial port
        KERNEL=="ttyACM0", MODE="0666"
        # Allow uinput as non-root user (in input group)
        KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
        # Sweep keyboard plover-HID non-root access.
        SUBSYSTEM=="hidraw", ATTRS{driver}=="hid-generic", MODE="0660", GROUP="input"

        # SF13TO external touchscreen: ignore the absolute-mouse HID interface so
        # the real multitouch node can deliver wl_touch (taps + one-finger scroll).
        ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="ILITEK ILITEK-TP Mouse", ENV{LIBINPUT_IGNORE_DEVICE}="1"

        # Per-panel digitizers -> DRM connectors. Niri reads WL_OUTPUT via libinput
        # (stock niri ignores it unless patched; see niri-libinput-wl-output.patch).
        ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="FTS3528:00 2808:1015", ENV{WL_OUTPUT}="${config.metadata.hardware.monitors.internal.connector}"
        ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="FTS3528:00 2808:1015 UNKNOWN", ENV{WL_OUTPUT}="${config.metadata.hardware.monitors.internal.connector}"
        ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="ILITEK ILITEK-TP", ENV{WL_OUTPUT}="${config.metadata.hardware.monitors.external.oled.connector}"

        # Limit battery charge to 80%
        SUBSYSTEM=="power_supply", KERNEL=="BAT0", ACTION=="add", ATTR{charge_control_end_threshold}="80"

        # Disable wakeup sources that cause immediate suspend resume on Steam Deck
        # WARNING: This was AI-generated, so I'm not sure if it's correct and if everything is needed
        ACTION=="add", SUBSYSTEM=="power_supply", KERNEL=="ACAD", ATTR{power/wakeup}="disabled"
        ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:00:01.2", ATTR{power/wakeup}="disabled"
        ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:00:08.3", ATTR{power/wakeup}="disabled"
        ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:00:08.1", ATTR{power/wakeup}="disabled"
        ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:04:00.3", ATTR{power/wakeup}="disabled"
        ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:04:00.4", ATTR{power/wakeup}="disabled"
        ACTION=="add", SUBSYSTEM=="acpi", KERNEL=="LNXPWRBN:00", ATTR{power/wakeup}="disabled"
        ACTION=="add", SUBSYSTEM=="acpi", KERNEL=="PNP0C0D:00", ATTR{power/wakeup}="disabled"
        ACTION=="add", SUBSYSTEM=="acpi", KERNEL=="PNP0C0A:00", ATTR{power/wakeup}="disabled"
        ACTION=="add", SUBSYSTEM=="acpi", KERNEL=="PNP0C0C:00", ATTR{power/wakeup}="disabled"
    '';

    hardware = {
        graphics = {
            enable = true;
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
    # systemd.sleep.extraConfig = ''
        # HibernateDelaySec=3h 
    # '';
    
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
