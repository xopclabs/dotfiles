{ config, lib, inputs, nix-colors, zmk-nix, ...}:

{
    imports = [ 
        ../../modules/default.nix 
        nix-colors.homeManagerModules.default
    ];
    config.modules = {
        # gui
        gtk.enable = true;
        floorp.enable = true;
        kitty.enable = true;
        hyprland.enable = true;
        vscode.enable = true;

        # cli
        nvim.enable = true;
        zsh.enable = true;
        tmux.enable = true;
        git.enable = true;
        gpg.enable = true;
        direnv.enable = true;
        ssh.enable = true;

        # system
        xdg.enable = true;
        sops.enable = true;
        packages.enable = true;
    };
    config.colorScheme = nix-colors.colorSchemes.nord;

}
