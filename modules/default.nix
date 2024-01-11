{ inputs, pkgs, config, ... }:

{
    home.stateVersion = "24.05";
    imports = [
        # gui
        ./firefox
        ./foot
        ./kitty
        ./dunst
        ./hyprland
        ./wofi
        ./waybar
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
