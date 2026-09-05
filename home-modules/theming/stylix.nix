{ pkgs, lib, config, options, inputs, ... }:

with lib;
let cfg = config.modules.theming.stylix;
in {
    options.modules.theming.stylix = { 
        enable = mkEnableOption "stylix";
        autoEnable = mkOption {
            type = types.bool;
            default = true;
        };
        colorScheme = mkOption {
            type = types.str;
            default = "${pkgs.base16-schemes}/share/themes/nord.yaml";
        };
    };
    config = mkIf cfg.enable {
        stylix = {
            enable = true;
            autoEnable = cfg.autoEnable;
            enableReleaseChecks = false;
            fonts = {
                sansSerif = {
                    name = "Ubuntu";
                    package = pkgs.ubuntu-sans;
                };
                serif = {
                    name = "Ubuntu";
                    package = pkgs.ubuntu-sans;
                };
                monospace = {
                    name = "Mononoki Nerd Font";
                    package = pkgs.nerd-fonts.mononoki;
                };
            };
            base16Scheme = cfg.colorScheme;

            targets = {
                vscode.enable = false;
                gnome.enable = false;
                gtk.enable = false;
                waybar.enable = false;
                tofi.enable = false;
                kitty.enable = false;
                btop.enable = false;
		        firefox.profileNames = [ "${config.home.username}" ];
            } // optionalAttrs (options.stylix.targets ? noctalia) {
                noctalia.enable = false;
            } // optionalAttrs (options.stylix.targets ? noctalia-shell) {
                noctalia-shell.enable = false;
            };
        };
    };
}
