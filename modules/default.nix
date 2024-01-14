{ inputs, pkgs, config, ... }:

{
    home.stateVersion = "24.05";
    imports = [
        # gui
        ./gtk
        ./firefox
        ./kitty
        ./dunst
        ./hyprland
        ./ags
        ./vscode

        # cli
        ./nvim
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
