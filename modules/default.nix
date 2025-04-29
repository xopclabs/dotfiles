{ inputs, pkgs, config, ... }:

{
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
