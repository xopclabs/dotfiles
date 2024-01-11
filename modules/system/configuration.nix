{ config, pkgs, inputs, ... }:

{
    # Remove unecessary preinstalled packages
    environment.defaultPackages = [ ];
    services.xserver.desktopManager.xterm.enable = false;

    programs.zsh.enable = true;

    # Install fonts
    fonts = {
        packages = with pkgs; [
            jetbrains-mono
            roboto
            openmoji-color
            (nerdfonts.override { fonts = [ "JetBrainsMono" "Mononoki" ]; })
        ];

        fontconfig = {
            hinting.autohint = true;
            defaultFonts = {
              emoji = [ "OpenMoji Color" ];
            };
        };
    };

    # Wayland stuff: enable XDG integration, allow sway to use brillo
    xdg = {
        autostart.enable = true;
        portal = {
            enable = true;
            extraPortals = with pkgs; [
                xdg-desktop-portal-wlr
                xdg-desktop-portal-gtk
            ];
            config.common.default = "*";
        };
    };

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

    # Set up locales (timezone and keyboard layout)
    time.timeZone = "Asia/Tbilisi";
    i18n.defaultLocale = "en_US.UTF-8";
    console = {
        font = "Lat2-Terminus16";
        keyMap = "us";
    };

    # Set up user and enable sudo
    users.users.xopc = {
        extraGroups = [ "input" "wheel" ];
        shell = pkgs.zsh;
        isNormalUser = true;
    };

    # Set up networking and secure it
    networking = {
        wireless.iwd.enable = true;
    };

    # Set environment variables
    environment.variables = {
        NIXOS_CONFIG = "$HOME/nix-config/nixos/configuration.nix";
        NIXOS_CONFIG_DIR = "$HOME/nix-config";
        XDG_DATA_HOME = "$HOME/.local/share";
        QT_QPA_PLATFORM = "wayland";
        XDG_CURRENT_DESKTOP = "Sway";
        PASSWORD_STORE_DIR = "$HOME/.local/share/password-store";
        GTK_RC_FILES = "$HOME/.local/share/gtk-1.0/gtkrc";
        GTK2_RC_FILES = "$HOME/.local/share/gtk-2.0/gtkrc";
        MOZ_ENABLE_WAYLAND = "1";
        ZK_NOTEBOOK_DIR = "$HOME/notes";
        EDITOR = "nvim";
        DIRENV_LOG_FORMAT = "";
        DISABLE_QT5_COMPAT = "0";
        TERM="xterm-kitty";
    };

    # Security 
    security = {
        sudo.enable = true;
        # Extra security
        protectKernelImage = true;
        # Swaylock
        pam.services.swaylock = {};
    };

    # Sound
    sound = {
        enable = true;
    };
    hardware.pulseaudio.enable = true;
    security.rtkit.enable = true;
    services.pipewire = {
        enable = false;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
    };
    hardware = {
        bluetooth.enable = true;
        opengl = {
            enable = true;
            driSupport = true;
        };
    };

    # Security
    services.clamav = {
        daemon.enable = true;
        updater.enable = true;
    };
    services.gnome.gnome-keyring.enable = true;
    # Do not touch
    system.stateVersion = "20.09";
}
