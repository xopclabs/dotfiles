{ config, pkgs, inputs, lib, ... }:

let
  corefonts-subset = pkgs.runCommand "corefonts-subset" {} ''
    mkdir -p $out/share/fonts/truetype
    # Copy only subset of fonts from corefonts
    for font in Times_New_Roman Arial Comic_Sans_MS; do
        echo $font
        cp "${pkgs.corefonts}/share/fonts/truetype/$font"*.ttf "$out/share/fonts/truetype/"
        chmod 444 "$out/share/fonts/truetype/$font"*.ttf
    done
  '';
in
{
    # Remove unecessary preinstalled packages
    environment.defaultPackages = [ pkgs.sudo ];
    services.xserver.desktopManager.xterm.enable = false;

    # Install fonts
    fonts = {
        packages = with pkgs; [
            #times-new-roman
            corefonts-subset
            noto-fonts
            noto-fonts-cjk-sans
            noto-fonts-extra
            jetbrains-mono
            roboto
            openmoji-color
            nerd-fonts.jetbrains-mono
            nerd-fonts.mononoki
        ];

        fontconfig = {
            hinting.autohint = true;
            defaultFonts = {
              serif = [  "Noto Serif" ];
              sansSerif = [ "DejaVu Sans" ];
              monospace = [ "Mononoki Nerd Font Mono" ];
              emoji = [ "OpenMoji Color" ];
            };
        };
    };

   programs.dconf.enable = true; 

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
        QT_QPA_PLATFORMTHEME = "qt5ct";
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
    environment.systemPackages = with pkgs; [ 
        libsForQt5.qtstyleplugin-kvantum
        libsForQt5.qt5ct
        kdePackages.qtstyleplugin-kvantum
        kdePackages.qt6ct
    ];

    # Binary caches
    nix.settings = {
        substituters = [
            "https://hyprland.cachix.org"
            "https://niri.cachix.org"
        ];
        trusted-public-keys = [
            "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
            "niri.cachix.org-1:WQkK2e/7zfNzYjlxY9++Tw6KhxSxqc3k3+l0SBhsAbE="
        ];
    };

    # Enable Hyprland with UWSM for proper session management
    programs.hyprland = {
        enable = true;
        withUWSM = true;
    };

}
