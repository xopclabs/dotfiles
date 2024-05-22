{
    description = "NixOS configuration";

    # All inputs for the system
    inputs = {
        home-manager.url = "github:xopclabs/home-manager/floorp-browser";
        home-manager.inputs.nixpkgs.follows = "nixpkgs";

        nur.url = "github:nix-community/NUR";

        nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

        sops-nix.url = "github:Mic92/sops-nix";

        nix-colors.url = "github:Misterio77/nix-colors";

        firefox-nordic.url = "github:EliverLara/firefox-nordic-theme";
        firefox-nordic.flake = false;

        tmux-sessionx.url = "github:omerxx/tmux-sessionx";
        
        zmk-nix.url = "/home/xopc/zmk-nix";
    };

    # All outputs for the system (configs)
    outputs = { home-manager, nixpkgs, ... }@inputs: 
        let
            system = "x86_64-linux";
            pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
            lib = nixpkgs.lib;

            mkSystem = pkgs: system: hostname: username:
                pkgs.lib.nixosSystem {
                    system = system;
                    modules = [
                        { networking.hostName = hostname; }
                        # General configuration (users, networking, sound, etc)
                        (./. + "/hosts/${hostname}/system/configuration.nix")
                        # Hardware config (bootloader, kernel modules, filesystems, etc)
                        (./. + "/hosts/${hostname}/system/hardware-configuration.nix")
                        {
                            home-manager = {
                                useUserPackages = true;
                                useGlobalPkgs = true;
                                extraSpecialArgs = { inherit inputs; };
                                users."${username}" = (./. + "/hosts/${hostname}/user.nix");
                            };
                            nixpkgs.overlays = [ inputs.nur.overlay ];
                            sops.defaultSopsFile = (./. + "/hosts/${hostname}/secrets.yaml");
                        }
                        inputs.home-manager.nixosModules.home-manager
                        inputs.sops-nix.nixosModules.sops
                    ];
                    specialArgs = { inherit inputs; };
                };

        in {
            nixosConfigurations = {
                #                                Architecture   Hostname Username
                laptop = mkSystem inputs.nixpkgs "x86_64-linux" "laptop" "xopc";
                #dev = mkSystem inputs.nixpkgs    "x86_64-linux" "dev"    "xopc";
            };
    };
}
