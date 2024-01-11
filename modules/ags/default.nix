{ inputs, pkgs, ... }:
{
    imports = [ inputs.ags.homeManagerModules.default ];

    home.packages = with pkgs; [
        sassc
    ];

    programs.ags = {
        enable = true;
        configDir = ./config;
        extraPackages = with pkgs; [
            libgtop
            libsoup_3
        ];
    };
}
