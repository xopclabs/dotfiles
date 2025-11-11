{ config, lib, inputs, ...}:

{
    imports = [
        ../../modules/default.nix
        ./home.nix
        inputs.nix-colors.homeManagerModules.default
        inputs.nixvim.homeModules.nixvim
    ];
    config.hardware = {
        monitors = {
            internal = {
                name = "BOE 0x06B7";
                mode = "1920x1080@60";
                scale = 1.0;
                position = "0,1080";
            };
            external = {
                name = "AOC 22V2WG5 0x000000BF";
                mode = "1920x1080@74.97";
                scale = 1.0;
                position = "0,0";
            };
        };

    };
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
            starship.enable = true;
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

        other = {
            kicad.enable = false;
            plover.enable = true;
        };

    };
    config.colorScheme = inputs.nix-colors.colorSchemes.nord;
}
