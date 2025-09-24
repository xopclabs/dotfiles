{ config, lib, inputs, ...}:

{
    imports = [
        ../../modules/default.nix
        ./sops.nix
        ./home.nix
        inputs.nix-colors.homeManagerModules.default
        inputs.nixvim.homeModules.nixvim
    ];
    config.hardware = {
        monitors = {
            internal = {
                name = "Valve Corporation ANX7530 U 0x00000001";
                mode = "800x1280@90";
                scale = 1.0;
                transform = "270";
                position = "320,1080";
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
            bars = {
                waybar = {
                    enable = true;
                };
            };
            launchers.tofi.enable = true;
            wm = {
                kanshi.enable = true;
                hyprland = {
                    enable = true;
                    extraAutostart = [
                        "[workspace 7 silent] steam"
                    ];
                };
                hypridle = {
                    enable = true;
                    dpmsInternal.timeout = 3 * 60;
                    dpmsExternal.timeout = 15 * 60;
                    lock.enable = false;
                    suspend.timeout = 30 * 60;
                };
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
            plover.enable = false;
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