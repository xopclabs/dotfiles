{ inputs, pkgs, config, ... }:

{
    home.stateVersion = "24.05";
    imports = [
        # gui
        ./hyprland
        ./waybar
        ./rofi
        ./gtk
        ./firefox
        ./kitty
        ./dunst
        ./vscode
        ./mpv
        ./zen
        ./kicad
        ./plover

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
        ./btop

        # system
        ./xdg
    	./packages
    	./scripts
    ];
}
