{ config, lib, inputs, ...}:

{
    imports = [ 
        ../../modules/default.nix 
        ./sops.nix
        ./home.nix
        inputs.nix-colors.homeManagerModules.default
	inputs.nixvim.homeManagerModules.nixvim
    ];
    config.modules = {
        cli = {
            zsh.enable = true;
            tmux = {
                enable = true;
                mouse.enable = true;
            };
            starship.enable = true;
            eza.enable = true;
            zoxide.enable = true;
            bat.enable = true;
            fzf.enable = true;
        };

        tools = {
            git = {
                enable = true;
                signingKey = "${config.home.homeDirectory}/.ssh/id_ed25519_laptop";
            };
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
            optional.enable = true;
        };
    };
    config.colorScheme = inputs.nix-colors.colorSchemes.nord;
}
