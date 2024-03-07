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
                xdg-desktop-portal-hyprland
                xdg-desktop-portal-gtk
            ];
            config = {
                common.default = [ "hyprland" "gtk" ];
            };
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


    # Screen sharing
    security.rtkit.enable = true;
    # enable pipewire with wlr support
    services.pipewire = {
        enable = true;
        wireplumber.enable = true;
    };
    xdg.portal.wlr.settings = {
        screencast = {
            output_name = "eDP-1";
            max_fps = 60;
            chooser_type = "simple";
            chooser_cmd = "${pkgs.slurp}/bin/slurp -f %o -or";		
        };
    };
    environment.systemPackages = with pkgs; [ xwaylandvideobridge ];

    # Hyprland cachix
    nix.settings = {
        substituters = ["https://hyprland.cachix.org"];
        trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
    };
}
