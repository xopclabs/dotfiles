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

        hyprlock.url = "github:hyprwm/hyprlock";
        #hyprland.url = "github:hyprwm/Hyprland";
    };

    # All outputs for the system (configs)
    outputs = { home-manager, nixpkgs, nur, nix-vscode-extensions, sops-nix, nix-colors, hyprlock, ... }@inputs: 
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
                                extraSpecialArgs = { inherit inputs; inherit nix-colors; };
                                # Home manager config (configures programs like firefox, zsh, eww, etc)
                                users.xopc = (./. + "/hosts/${hostname}/user.nix");
                                sharedModules = [
                                    sops-nix.homeManagerModules.sops
                                    hyprlock.homeManagerModules.default
                                    #hyprland.homeManagerModules.default
                                ];
                            };
                            nixpkgs.overlays = [
                                # Add nur overlay for Firefox addons
                                nur.overlay
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
