{ config, lib, inputs, ...}:

{
    imports = [ 
        ../../modules/default.nix 
        ./sops.nix
        ./home.nix
        inputs.nix-colors.homeManagerModules.default
        inputs.nixvim.homeManagerModules.nixvim
        inputs.stylix.homeModules.stylix
    ];
    config.modules = {
        desktop = {
            bars.waybar.enable = true;
            launchers.tofi.enable = true;
            wm = {
                hyprland.enable = true;
                hypridle.enable = true;
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
            starship.enable = true;
            eza.enable = true;
            zoxide.enable = true;
            bat.enable = true;
            fzf.enable = true;
        };

        tools = {
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
            vscode.enable = true;
            cursor.enable = true;
            nvim.enable = true;
        };

        fileManagers = {
            yazi.enable = true;
            nautilus.enable = true;
        };

        gui = {
            flameshot.enable = false;
            kicad.enable = false;
            plover.enable = true;
        };

        browsers = {
            firefox.enable = true;
            chromium.enable = true;
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
