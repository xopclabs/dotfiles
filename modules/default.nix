{ inputs, pkgs, config, lib, ... }:

with lib;
let
    # Select a default item based on priorities when multiple items can be enabled
    selectDefault = { 
        cfg,                 # The module config
        priorities,          # List of items in priority order
        itemField ? "enable" # The field to check for enabled items (default: enable)
    }: let
        enabledItems = filter (item: cfg.${item}.${itemField} or false) priorities;
    in
        if enabledItems == [] then null else head enabledItems;
in
{
    # Export the utility functions
    _module.args = {
        utils = {
            inherit selectDefault;
        };
    };

    home.stateVersion = "24.05";
    imports = [
        # gui
        ./hyprland
        ./waybar
        ./rofi
        ./gtk
        ./browsers
        ./kitty
        ./dunst
        ./vscode
        ./mpv
        ./kicad
        ./plover
        ./flameshot

        # cli
        ./awscli
        ./nvim
        ./udiskie
        ./tmux
        ./zsh
        ./starship
        ./git
        ./gpg
        ./ssh
        ./nh
        ./ranger
        ./yazi
        ./btop
        ./fzf
        ./eza
        ./bat
        ./zoxide
        ./tldr

        # system
        ./xdg
    	./packages
    	./scripts
    ];
}
