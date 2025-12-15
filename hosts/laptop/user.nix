{ config, lib, inputs, ...}:

{
    imports = [
        ../../home-modules
        ./home.nix
        ./metadata.nix
        inputs.nix-colors.homeManagerModules.default
        inputs.nixvim.homeModules.nixvim
    ];
    
    config.modules = {
	    desktop.other.gtk.enable = true;

        theming = {
            stylix.enable = true;
        };

        cli = {
            zsh.enable = true;
            tmux = {
                enable = true;
                mouse.enable = true;
            };
            starship = {
                enable = true;
                userBlockColor = "teal";
            };
            eza.enable = true;
            zoxide.enable = true;
            bat.enable = true;
            fzf.enable = true;

            git.enable = true;
            gpg.enable = false;
            ssh.enable = true;
            udiskie.enable = true;
            btop.enable = true;
            nh.enable = true;
            tldr.enable = true;
            scripts.enable = true;
        };

        editors = {
            nvim.enable = true;
        };

        fileManagers = {
            yazi.enable = true;
        };

        packages = {
            common.enable = true;
        };

    };
    config.colorScheme = inputs.nix-colors.colorSchemes.nord;
}
