{ inputs, pkgs, config, ... }:

{
    home.stateVersion = "24.05";
    imports = [
        # gui
        ./stylix
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
