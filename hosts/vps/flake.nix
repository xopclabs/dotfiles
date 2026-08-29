{
    description = "VPS NixOS configuration";

    inputs = {
        dotfiles.url = "path:../..";
        wallpaper-generator.url = "path:/home/vps/wallpaper-generator";
        wallpaper-generator.inputs.nixpkgs.follows = "dotfiles/nixpkgs";
    };

    outputs = { dotfiles, wallpaper-generator, ... }: {
        nixosConfigurations.vps = dotfiles.nixosConfigurations.vps.extendModules {
            modules = [
                wallpaper-generator.nixosModules.default
            ];
        };
    };
}
