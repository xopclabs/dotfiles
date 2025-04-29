{ pkgs, inputs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.gtk;

    # gtk-theme = "Nordic";
in {
    options.modules.gtk = { enable = mkEnableOption "gtk"; };

    config = mkIf cfg.enable {
        home = {
            packages = with pkgs; [
                libadwaita
                adw-gtk3
                font-awesome
                nerd-fonts.ubuntu
                nerd-fonts.ubuntu-mono
                nerd-fonts.fantasque-sans-mono
                nerd-fonts.fira-code
                nerd-fonts.mononoki
                nordic
                dconf
                papirus-nord
            ];
            sessionVariables = {
                #XCURSOR_THEME = cursor-theme;
                XCURSOR_SIZE = "24";
                # GTK_THEME = gtk-theme;
            };
            file = {
                /*
                ".local/share/fonts" = {
                    recursive = true;
                    source = "${pkgs.nerd-fonts.m}/share/fonts/truetype/NerdFonts";
                };
                ".fonts" = {
                    recursive = true;
                    source = "${pkgs.nerd-fonts}/share/fonts/truetype/NerdFonts";
                };
                */
                # ".config/gtk-4.0/gtk.css" = {
                #     text = ''
                #     window.messagedialog .response-area > button,
                #     window.dialog.message .dialog-action-area > button,
                #     .background.csd{
                #         border-radius: 0;
                #     }
                #     '';
                # };
            };
        };

        gtk.enable = true;
        stylix.targets.gtk.extraCss = ''
            headerbar, .titlebar,
            .csd:not(.popup):not(tooltip):not(messagedialog) decoration{
                border-radius: 0;
            }
        '';

        qt = {
            enable = true;
            # platformTheme.name = "qtct";
            # style = {
                # name = "kvantum";
                # package = pkgs.nordic;
            # };
        };
        # xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
        #     [General]
        #     theme=${gtk-theme}
        # '';
        #  xdg.configFile."Kvantum/${gtk-theme}".source = "${pkgs.nordic}/share/Kvantum/${gtk-theme}";
    };
}
