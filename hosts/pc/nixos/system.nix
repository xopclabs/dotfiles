{ config, pkgs, inputs, lib, ... }:

let
    initrdConsoleFont = pkgs.runCommand "ter-v32b.psf" { nativeBuildInputs = [ pkgs.gzip ]; } ''
        gzip -dc ${pkgs.terminus_font}/share/consolefonts/ter-v32b.psf.gz > $out
    '';
in
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
        initrd = {
            availableKernelModules = [ "amdgpu" ];
            luks.devices.cryptroot = {
                # Use the TPM2 token enrolled by systemd-cryptenroll. If Secure Boot
                # PCR 7 or the PIN check fails, systemd-cryptsetup falls back to the
                # regular LUKS passphrase slot.
                crypttabExtraOpts = [ "tpm2-device=auto" ];
            };
            systemd = {
                contents."/share/consolefonts/ter-v32b.psf".source = initrdConsoleFont;
                extraBin.setfont = "${pkgs.kbd}/bin/setfont";
                services.luks-console-font = {
                    wantedBy = [ "cryptsetup-pre.target" ];
                    before = [ "cryptsetup-pre.target" ];
                    unitConfig.DefaultDependencies = "no";
                    serviceConfig.Type = "oneshot";
                    script = ''
                        # The built-in 5" panel is physically landscape but mounted portrait-ish.
                        # Keep the console unrotated and use a larger font before the LUKS prompt.
                        # echo 0 > /sys/class/graphics/fbcon/rotate_all || true
                        setfont -C /dev/console /share/consolefonts/ter-v32b.psf || true
                    '';
                };
            };
        };
        kernelParams = [ "fbcon=rotate:0" ];
        loader = {
            efi = {
                canTouchEfiVariables = true;
                efiSysMountPoint = "/boot";
            };

            grub = {
                enable = true;
                device = "nodev";
                efiSupport = true;
                enableCryptodisk = false;
            };

            systemd-boot = {
                enable = false;
                editor = false;
            };
            timeout = 2;
        };
    };

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
        # (stock niri ignores it unless patched; see patches/niri/).
        ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="ILITEK ILITEK-TP", ENV{WL_OUTPUT}="${config.metadata.hardware.monitors.external.oled.connector}"
    '';

    hardware = {
        enableRedistributableFirmware = true;
        graphics.enable = true;
    };

    # NFS share client
    fileSystems."/mnt/nas" = {
        device = "192.168.254.10:/mnt/raid_pool/shared";
        fsType = "nfs";
        options = [ "x-systemd.automount" "noauto" ];
    };

    services.upower.enable = true;
    # Automounting
    services.gvfs.enable = true;
    services.devmon.enable = true;
    services.udisks2.enable = true;

    powerManagement.enable = true;
    services.thermald.enable = true;
    services.power-profiles-daemon.enable = true;
    services.fwupd.enable = true;

    # Docker support
    virtualisation.docker = {
        enable = true;
        enableOnBoot = true;
        rootless.enable = true;
    };

    # System env variables
    environment.variables = {
        NIXOS_CONFIG = "$HOME/dotfiles/hosts/pc/nixos/configuration.nix";
        NIXOS_CONFIG_DIR = "$HOME/dotfiles";
        NH_FLAKE = "$HOME/dotfiles/hosts/pc";
        GTK_RC_FILES = "$HOME/.local/share/gtk-1.0/gtkrc";
        GTK2_RC_FILES = "$HOME/.local/share/gtk-2.0/gtkrc";
        MOZ_ENABLE_WAYLAND = "1";
        EDITOR = "nvim";
        TERM = "xterm-kitty";
    };

    # Do not touch
    system.stateVersion = "24.11";
}
