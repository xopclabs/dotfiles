{ config, lib, inputs, ...}:

{
    imports = [ 
        ../../modules/default.nix 
        inputs.nix-colors.homeManagerModules.default
        inputs.sops-nix.homeManagerModules.sops
        inputs.hyprlock.homeManagerModules.default
        #inputs.hyprland.homeManagerModules.default
    ];
    config.modules = {
        # gui
        gtk.enable = true;
        floorp.enable = true;
        firefox.enable = true;
        kitty.enable = true;
        hyprland.enable = true;
        waybar.enable = true;
        rofi.enable = true;
        vscode.enable = true;
        mpv.enable = true;

        # cli
        awscli.enable = true;
        udiskie.enable = true;
        nvim.enable = true;
        zsh.enable = true;
        tmux.enable = true;
        git.enable = true;
        gpg.enable = true;
        ssh.enable = true;

        # system
        xdg.enable = true;
        sops.enable = true;
        packages.enable = true;
        scripts.enable = true;
    };
    config.colorScheme = inputs.nix-colors.colorSchemes.nord;
}
