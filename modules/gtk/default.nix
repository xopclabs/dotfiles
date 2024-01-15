{ pkgs, inputs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.gtk;

    gtk-theme = "Nordic";

    nerdfonts = (pkgs.nerdfonts.override { fonts = [
        "Ubuntu"
        "UbuntuMono"
        "CascadiaCode"
        "FantasqueSansMono"
        "FiraCode"
        "Mononoki"
    ]; });
in {
    options.modules.gtk = { enable = mkEnableOption "gtk"; };
    config = mkIf cfg.enable {
        home = {
            packages = with pkgs; [
                libadwaita
                adw-gtk3
                font-awesome
                nerdfonts
                nordic
                dconf
                papirus-nord
                # qogir-icon-theme
                # whitesur-icon-theme
                # colloid-icon-theme
                # qogir-theme
                # yaru-theme
                # whitesur-gtk-theme
                # orchis-theme
            ];
            sessionVariables = {
                #XCURSOR_THEME = cursor-theme;
                XCURSOR_SIZE = "24";
                GTK_THEME = gtk-theme;
            };
            file = {
                ".local/share/fonts" = {
                    recursive = true;
                    source = "${nerdfonts}/share/fonts/truetype/NerdFonts";
                };
                ".fonts" = {
                    recursive = true;
                    source = "${nerdfonts}/share/fonts/truetype/NerdFonts";
                };
                ".config/gtk-4.0/gtk.css" = {
                    text = ''
                    window.messagedialog .response-area > button,
                    window.dialog.message .dialog-action-area > button,
                    .background.csd{
                        border-radius: 0;
                    }
                    '';
                };
            };
        };

        gtk = {
            enable = true;
            font.name = "Mononoki Nerd Font";
            theme.name = gtk-theme;
            iconTheme.name = "Papirus";
            gtk3.extraCss = ''
                headerbar, .titlebar,
                .csd:not(.popup):not(tooltip):not(messagedialog) decoration{
                    border-radius: 0;
                }
            '';
        };

        qt = {
            enable = true;
            platformTheme = "kde";
        };
    };
}
