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
        desktop = {
            bars.waybar.enable = true;
            launchers.tofi.enable = true;
            wm = {
                kanshi.enable = true;
                hyprland.enable = true;
                hypridle.enable = true;
                scripts.enable = true;
            };
            other = {
                xdg.enable = true;
                gtk.enable = true;
            };
        };

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
            awscli.enable = true;
            udiskie.enable = true;
            btop.enable = true;
            nh.enable = true;
            tldr.enable = true;
            scripts.enable = true;
        };

        terminals = {
            kitty.enable = true;
        };

        editors = {
            vscode.enable = false;
            cursor.enable = false;
            nvim.enable = true;
        };

        fileManagers = {
            yazi.enable = true;
            nautilus.enable = true;
        };

        browsers = {
            firefox.enable = true;
            chromium.enable = false;
        };

        players = {
            video.mpv.enable = true;
            video.vlc.enable = true;
        };

        packages = {
            common.enable = true;
            optional.enable = true;
        };

    };
    config.colorScheme = inputs.nix-colors.colorSchemes.nord;
}
