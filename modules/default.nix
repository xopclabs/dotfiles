{ inputs, pkgs, config, ... }:

{
    home.stateVersion = "24.05";
    imports = [
        # gui
        ./hyprland
        ./waybar
        ./rofi
        ./gtk
        ./floorp
        ./firefox
        ./kitty
        ./dunst
        ./vscode
        ./mpv

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
