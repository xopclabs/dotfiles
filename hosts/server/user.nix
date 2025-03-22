{ config, lib, inputs, ...}:

{
    imports = [ 
        ../../modules/default.nix 
        inputs.nix-colors.homeManagerModules.default
    ];
    config.modules = {
        # cli
        zsh.enable = true;
        tmux.enable = true;
        git.enable = true;
        nh.enable = true;
        ranger.enable = true;
        btop.enable = true;

        # system
        xdg.enable = true;
    };
    config.colorScheme = inputs.nix-colors.colorSchemes.nord;

    # Make non-nix packages work
    config.targets.genericLinux.enable = true;
    # Let home-manager manage itself
    config.programs.home-manager.enable = true;

}
