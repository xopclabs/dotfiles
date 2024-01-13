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
        ./wofi
        ./waybar
        ./ags
        ./vscode
        ./flameshot

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
