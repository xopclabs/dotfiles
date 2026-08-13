{ config, lib, inputs, ...}:

{
    imports = [ 
        ../../home-modules
        ./home.nix
        inputs.nix-colors.homeManagerModules.default
	    inputs.nixvim.homeModules.nixvim
    ];

    config.modules = {
        theming.stylix.enable = true;
        desktop.other.gtk.enable = false;

        cli = {
            zsh.enable = true;
            tmux = {
                enable = true;
                statusPosition = "bottom";
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
    # Headless: stylix autoEnable writes dconf, and HM activation fails without a session.
    config.stylix.autoEnable = lib.mkForce false;
    config.dconf.enable = lib.mkForce false;
}
