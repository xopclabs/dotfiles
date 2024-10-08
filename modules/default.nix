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

        # cli
        ./awscli
        ./nvim
        ./udiskie
        ./tmux
        ./zsh
        ./git
        ./gpg
        ./ssh
        ./nh
        ./ranger

        # system
        ./xdg
    	./packages
    	./scripts
    ];
}
