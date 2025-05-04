{
    description = "NixOS configuration";

    # All inputs for the system
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
        home-manager.url = "github:nix-community/home-manager";
        home-manager.inputs.nixpkgs.follows = "nixpkgs";

        disko.url = "github:nix-community/disko";
        disko.inputs.nixpkgs.follows = "nixpkgs";

        nur.url = "github:nix-community/NUR";

        nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

        sops-nix.url = "github:Mic92/sops-nix";

        nix-colors.url = "github:Misterio77/nix-colors";

        firefox-nordic.url = "github:EliverLara/firefox-nordic-theme";
        firefox-nordic.flake = false;

        tmux-sessionx.url = "github:omerxx/tmux-sessionx";

        plover.url = "github:dnaq/plover-flake";

        nixvim.url = "github:nix-community/nixvim";
        nixvim.inputs.nixpkgs.follows = "nixpkgs";
    };

    # All outputs for the system (configs)
    outputs = { home-manager, nixpkgs, ... }@inputs:
        let
            mkSystem = pkgs: system: hostname: username: useHomeManager:
                pkgs.lib.nixosSystem {
                    system = system;
                    modules = [
                        { networking.hostName = hostname; }
                        # General configuration (users, networking, sound, etc)
                        (./. + "/hosts/${hostname}/system/configuration.nix")
                        # Hardware config (bootloader, kernel modules, filesystems, etc)
                        (./. + "/hosts/${hostname}/system/hardware-configuration.nix")
                        inputs.disko.nixosModules.disko
                        inputs.sops-nix.nixosModules.sops
                        {
                            nixpkgs.overlays = [ inputs.nur.overlays.default ];
                            sops.defaultSopsFile = (./. + "/hosts/${hostname}/secrets.yaml");
                        }
                    ] ++ (if useHomeManager then [
                        inputs.home-manager.nixosModules.home-manager
                        {
                            home-manager = {
                                useUserPackages = true;
                                useGlobalPkgs = true;
                                extraSpecialArgs = { inherit inputs; };
                                users."${username}" = (./. + "/hosts/${hostname}/user.nix");
                            };
                        }
                    ] else []);
                    specialArgs = { inherit inputs; };
                };

            mkHome = pkgs: system: hostname: username:
                home-manager.lib.homeManagerConfiguration {
                    pkgs = import nixpkgs {
                        system = system;
                        overlays = [ inputs.nur.overlays.default ];
                        config = {
                            allowUnfree = true;
                        };
                    };
                    modules = [
                        (./. + "/hosts/${hostname}/user.nix")
    			        inputs.sops-nix.homeManagerModules.sops
                        inputs.nixvim.homeManagerModules.nixvim
                        {
                            home = {
                                username = username;
                                homeDirectory = "/home/${username}";
                            };
                        }
                    ];
                    extraSpecialArgs = { inherit inputs; };
                };

        in {
            nixosConfigurations = {
                #                                 Architecture   Hostname  Username  UseHomeManager
                laptop  = mkSystem inputs.nixpkgs "x86_64-linux" "laptop"  "xopc"    false;
                homelab = mkSystem inputs.nixpkgs "x86_64-linux" "homelab" "homelab" false;
            };
            homeConfigurations = {
                #                               Architecture   Hostname  Username
                xopc    = mkHome inputs.nixpkgs "x86_64-linux" "laptop"  "xopc";
                homelab = mkHome inputs.nixpkgs "x86_64-linux" "homelab" "homelab";
                pleyba  = mkHome inputs.nixpkgs "x86_64-linux" "work"    "pleyba";
            };
    };
}
