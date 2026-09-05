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
            shells.noctalia.enable = true;
            wm = {
                hyprland.enable = false;
                niri.enable = true;
                wallpaperRotate.enable = true;
                hypridle = {
                    enable = true;
                    dpmsInternal.timeout = 3 * 60;
                    dpmsExternal.timeout = 5 * 60;
                    suspend.timeout = 60 * 60;
                    lock.enable = false;
                };
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
            easyeffects.enable = false;
        };

        browsers = {
            firefox.enable = true;
            chromium.enable = true;
        };

        media = {
            video.mpv.enable = true;
            video.vlc.enable = true;
            audio = {
                feishin.enable = true;
                kew.enable = true;
            };
        };

        packages = {
            common.enable = true;
            optional.enable = true;
        };

        other = {
            kicad.enable = false;
            plover.enable = false;
            minecraft.enable = true;
            androidcam.enable = true;
            autofirma.enable = false;
        };
    };

    config.colorScheme = inputs.nix-colors.colorSchemes.nord;
}
