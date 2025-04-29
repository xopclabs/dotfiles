{ inputs, pkgs, config, lib, ... }:

with lib;
let
    # Select a default item based on priorities when multiple items can be enabled
    selectDefault = { cfg, priorities, itemField ? "enable" }: 
    let
        enabledItems = filter (item: cfg.${item}.${itemField} or false) priorities;
    in
        if enabledItems == [] then null else head enabledItems;
in
{
    home.stateVersion = "24.05";
    imports = [
        # meta-modules
        ./browsers
        ./file_managers
        ./editors
        ./cli
        ./tools
        ./gui

        # gui
        ./hyprland
        ./waybar
        ./rofi
        ./mpv

        # system
        ./xdg
    	./packages
    	./scripts
    ];

    # Export the utility functions
    _module.args = {
        utils = {
            inherit selectDefault;
        };
    };

}
