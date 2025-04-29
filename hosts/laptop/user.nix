{ config, lib, inputs, ...}:

{
    imports = [ 
        ../../modules/default.nix 
        ./sops.nix
        ./home.nix
        inputs.nix-colors.homeManagerModules.default
    ];
    config.modules = {
        # essentials
        git.enable = true;
        gpg.enable = false;
        ssh.enable = true;
        xdg = {
            enable = true;
            video-player = "vlc.desktop";
        };

        # gui
        stylix.enable = true;
        gtk.enable = true;
        firefox.enable = true;
        kitty.enable = true;
        hyprland.enable = true;
        hypridle.enable = true;
        waybar.enable = true;
        rofi.enable = true;
        vscode.enable = true;
        mpv.enable = true;
        kicad.enable = true;
        plover.enable = true;
        flameshot.enable = true;

        # cli
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

        # cli tools
        awscli.enable = true;
        udiskie.enable = true;
        nvim.enable = true;
        yazi.enable = true;
        btop.enable = true;
        nh.enable = true;
        tldr.enable = true;

        # extras
        packages.enable = true;
        scripts.enable = true;
    };
    config.colorScheme = inputs.nix-colors.colorSchemes.nord;
}
