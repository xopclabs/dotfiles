{ config, lib, inputs, ...}:

{
    imports = [ ../../modules/default.nix ];
    config.modules = {
        # gui
        gtk.enable = true;
        firefox.enable = true;
        kitty.enable = true;
        dunst.enable = true;
        hyprland.enable = true;
        wofi.enable = true;
        vscode.enable = true;
        flameshot.enable = true;

        # cli
        nvim.enable = true;
        zsh.enable = true;
        git.enable = true;
        gpg.enable = true;
        direnv.enable = true;
        ssh.enable = true;

        # system
        xdg.enable = true;
        sops.enable = true;
        packages.enable = true;
    };
}
