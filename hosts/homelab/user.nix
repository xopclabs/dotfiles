{ config, lib, inputs, ...}:

{
    imports = [ 
        ../../home-modules
        ./home.nix
        inputs.nix-colors.homeManagerModules.default
	    inputs.nixvim.homeModules.nixvim
    ];

    config.modules = {
        theming = {
            stylix = {
                enable = true;
                autoEnable = false;
            };
        };

        cli = {
            zsh.enable = true;
            tmux = {
                enable = true;
                statusPosition = "bottom";
                prefixKey = "C-Space";
            };
            starship = {
                enable = true;
                userBlockColor = "yellow";
            };
            eza.enable = true;
            zoxide.enable = true;
            bat.enable = true; 
            fzf.enable = true;

            git.enable = true;
            gpg.enable = false;
            ssh.enable = true;
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
