{ config, lib, pkgs, inputs, ... }:

{
    imports = [
        ../../home-modules
        ./home.nix
        ./metadata.nix
        inputs.nix-colors.homeManagerModules.default
        inputs.nixvim.homeModules.nixvim
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
            git.enable = true;
            ssh.enable = true;
            btop.enable = true;
            nh.enable = true;
            tldr.enable = true;
            scripts.enable = true;
        };
        editors.nvim.enable = true;
        fileManagers.yazi.enable = true;
    };

    # The shared common package set also includes desktop applications.
    config.home.packages = with pkgs; [
        curl wget ripgrep rsync
        util-linux iputils usbutils pciutils dig ps
        zip unzip _7zz
        lm_sensors age sops
        dust duf ncdu gh
    ];
    config.colorScheme = inputs.nix-colors.colorSchemes.nord;
}
