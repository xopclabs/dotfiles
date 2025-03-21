{ config, lib, inputs, ...}:

{
    imports = [ 
        ../../modules/default.nix 
        inputs.nix-colors.homeManagerModules.default
    ];
    config.modules = {
        # cli
        awscli.enable = false;
        nvim.enable = false;
        zsh.enable = false;
        tmux.enable = true;
        git.enable = true;
        gpg.enable = false;
        ssh.enable = false;
        nh.enable = true;
        ranger.enable = true;
        btop.enable = true;

        # system
        xdg.enable = true;
    };
    config.colorScheme = inputs.nix-colors.colorSchemes.nord;

    # Let home-manager manage itself
    config.programs.home-manager.enable = true;

}
