{
    description = "NixOS configuration";

    # All inputs for the system
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

        home-manager = {
            url = "github:nix-community/home-manager";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        nur = {
            url = "github:nix-community/NUR";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        nix-vscode-extensions = {
            url = "github:nix-community/nix-vscode-extensions";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        sops-nix = {
            url = "github:Mic92/sops-nix";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        ags.url = "github:Aylur/ags";
        nordic-gtk = {
            url = "github:EliverLara/Nordic";
            flake = false;
        };
    };

    # All outputs for the system (configs)
    outputs = { home-manager, nixpkgs, nur, nix-vscode-extensions, sops-nix, ... }@inputs: 
        let
            system = "x86_64-linux"; #current system
            pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
            lib = nixpkgs.lib;

            mkSystem = pkgs: system: hostname:
                pkgs.lib.nixosSystem {
                    system = system;
                    modules = [
                        { networking.hostName = hostname; }
                        # General configuration (users, networking, sound, etc)
                        ./modules/system/configuration.nix
                        # Hardware config (bootloader, kernel modules, filesystems, etc)
                        (./. + "/hosts/${hostname}/hardware-configuration.nix")
                        {
                            home-manager = {
                                useUserPackages = true;
                                useGlobalPkgs = true;
                                extraSpecialArgs = { inherit inputs; };
                                # Home manager config (configures programs like firefox, zsh, eww, etc)
                                users.xopc = (./. + "/hosts/${hostname}/user.nix");
                                sharedModules = [
                                    inputs.sops-nix.homeManagerModules.sops
                                ];
                            };
                            nixpkgs.overlays = [
                                # Add nur overlay for Firefox addons
                                nur.overlay
                                (import ./overlays)
                            ];
                        }
                        home-manager.nixosModules.home-manager
                        sops-nix.nixosModules.sops
                    ];
                    specialArgs = { inherit inputs; };
                };

        in {
            nixosConfigurations = {
                # Now, defining a new system is can be done in one line
                #                                Architecture   Hostname
                laptop = mkSystem inputs.nixpkgs "x86_64-linux" "laptop";
            };
    };
}
