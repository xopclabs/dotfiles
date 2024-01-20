{ inputs, pkgs, config, ... }:

{
    home.stateVersion = "24.05";
    imports = [
        # gui
        ./gtk
        ./floorp
        ./kitty
        ./dunst
        ./hyprland
        ./ags
        ./vscode

        # cli
        ./nvim
        ./udiskie
        ./tmux
        ./zsh
        ./git
        ./gpg
        ./direnv
        ./ssh

        # system
        ./xdg
        ./sops
    	./packages
    ];
}
