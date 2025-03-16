{ config, lib, inputs, ...}:

{
    imports = [ 
        ../../modules/default.nix 
        ./home.nix
        inputs.nix-colors.homeManagerModules.default
    ];
    config.modules = {
        # cli
        awscli.enable = false;
        nvim.enable = false;
        zsh.enable = true;
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
}
