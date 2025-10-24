{ config, pkgs, lib, inputs, ... }:

{
    imports = [ inputs.nix-minecraft.nixosModules.minecraft-servers ];
    nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];

    users.groups.minecraft.members = [ "homelab" ];

    services.minecraft-servers = {
        enable = true;
        eula = true;
        openFirewall = true;

        servers.distant-horizons = {
            enable = true;
            autoStart = false;
            package = pkgs.fabricServers.fabric-1_21_10;

            jvmOpts = "-Xms4G -Xmx8G";

            serverProperties = {
                difficulty = "hard";
                hardcore = true;
                gamemode = 0;
                spawn-monsters = true;
                level-seed = "";
                max-players = 2;
                motd = "socorro...";
                online-mode = false;
                pvp = true;
                view-distance = 10;
                simulation-distance = 12;
                spawn-protection = 16;
                white-list = false;
            };

            symlinks = {
                mods = pkgs.linkFarmFromDrvs "mods" (
                    builtins.attrValues {
                        distant-horizons = pkgs.fetchurl {
                            url = "https://cdn.modrinth.com/data/uCdwusMi/versions/9Y10ZuWP/DistantHorizons-2.3.6-b-1.21.10-fabric-neoforge.jar";
                            sha512 = "1b1b70b7ec6290d152a5f9fa3f2e68ea7895f407c561b56e91aba3fdadef277cd259879676198d6481dcc76a226ff1aa857c01ae9c41be3e963b59546074a1fc";
                        };
                        fabric-api = pkgs.fetchurl {
                            url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/lxeiLRwe/fabric-api-0.136.0%2B1.21.10.jar";
                            sha512 = "d6ad5afeb57dc6dbe17a948990fc8441fbbc13a748814a71566404d919384df8bd7abebda52a58a41eb66370a86b8c4f910b64733b135946ecd47e53271310b5";
                        };
                    }
                );
            };
        };
    };
}