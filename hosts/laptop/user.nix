{ config, lib, inputs, ...}:

{
    imports = [ 
        ../../modules/default.nix 
        ./sops.nix
        ./home.nix
        inputs.nix-colors.homeManagerModules.default
    ];
    config.modules = {
        browsers = {
            firefox.enable = true;
        };
        fileManagers = {
            yazi.enable = true;
            nautilus.enable = true;
        };
        editors = {
            vscode.enable = true;
            cursor.enable = true;
            nvim.enable = true;
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
        };
        gui = {
            kitty.enable = true;
            flameshot.enable = true;
            kicad.enable = true;
            plover.enable = true;
        };
        desktop = {
            bars.waybar.enable = true;
            launchers.rofi.enable = true;
            wm.hyprland.enable = true;
            wm.hypridle.enable = true;
            other.xdg.enable = true;
            other.gtk.enable = true;
        };
        players = {
            video.mpv.enable = true;
            video.vlc.enable = true;
        };

        # extras
        packages.enable = true;
        scripts.enable = true;
    };
    config.colorScheme = inputs.nix-colors.colorSchemes.nord;
}
