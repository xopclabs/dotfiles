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
        waybar.url = "github:Alexays/Waybar";
        #hyprland.url = "github:hyprwm/Hyprland";
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
                        ./modules/system/configuration.nix
                        # Hardware config (bootloader, kernel modules, filesystems, etc)
                        (./. + "/hosts/${hostname}/hardware-configuration.nix")
                        {
                            home-manager = {
                                useUserPackages = true;
                                useGlobalPkgs = true;
                                extraSpecialArgs = { inherit inputs; };
                                users."${username}" = (./. + "/hosts/${hostname}/user.nix");
                            };
                            nixpkgs.overlays = [ inputs.nur.overlay ];
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
