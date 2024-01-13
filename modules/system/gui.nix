{ config, pkgs, inputs, ... }:

{
    # Remove unecessary preinstalled packages
    environment.defaultPackages = [ ];
    services.xserver.desktopManager.xterm.enable = false;

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

    # Set environment variables
    environment.variables = {
        XDG_DATA_HOME = "$HOME/.local/share";
        QT_QPA_PLATFORM = "wayland";
        XDG_CURRENT_DESKTOP = "Sway";
        MOZ_ENABLE_WAYLAND = "1";
        DIRENV_LOG_FORMAT = "";
        DISABLE_QT5_COMPAT = "0";
    };
}
