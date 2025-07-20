{ pkgs, lib, config, inputs, ... }:

with lib;
let cfg = config.modules.theming.stylix;
in {
    options.modules.theming.stylix = { 
        enable = mkEnableOption "stylix";
        colorScheme = mkOption {
            type = types.str;
            default = "${pkgs.base16-schemes}/share/themes/nord.yaml";
        };
    };
    config = mkIf cfg.enable {
        stylix = {
            enable = true;
            autoEnable = true;
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
            };
        };
    };
}
