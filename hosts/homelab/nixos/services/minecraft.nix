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
            package = pkgs.fabricServers.fabric-1_21_8;

            jvmOpts = "-Xms4G -Xmx8G -XX:+UnlockExperimentalVMOptions -XX:+UnlockDiagnosticVMOptions -XX:+AlwaysActAsServerClassMachine -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+UseNUMA -XX:NmethodSweepActivity=1 -XX:ReservedCodeCacheSize=400M -XX:NonNMethodCodeHeapSize=12M -XX:ProfiledCodeHeapSize=194M -XX:NonProfiledCodeHeapSize=194M -XX:-DontCompileHugeMethods -XX:MaxNodeLimit=240000 -XX:NodeLimitFudgeFactor=8000 -XX:+UseVectorCmov -XX:+PerfDisableSharedMem -XX:+UseFastUnorderedTimeStamps -XX:+UseCriticalJavaThreadPriority -XX:ThreadPriorityPolicy=1 -XX:+UseG1GC -XX:MaxGCPauseMillis=130 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=28 -XX:G1HeapRegionSize=16M -XX:G1ReservePercent=20 -XX:G1MixedGCCountTarget=3 -XX:InitiatingHeapOccupancyPercent=10 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=0 -XX:SurvivorRatio=32 -XX:MaxTenuringThreshold=1 -XX:G1SATBBufferEnqueueingThresholdPercent=30 -XX:G1ConcMarkStepDurationMillis=5 -XX:G1ConcRSHotCardLimit=16 -XX:G1ConcRefinementServiceIntervalMillis=150";

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

            operators = {
                otter = {
                    uuid = "ae76cd23-ef71-38d5-8748-cd6b0df947ef";
                    level = 4;
                    bypassesPlayerLimit = true;
                };
            };

            symlinks = {
                mods = pkgs.linkFarmFromDrvs "mods" (
                    builtins.attrValues {
                        distant-horizons = pkgs.fetchurl {
                            url = "https://cdn.modrinth.com/data/uCdwusMi/versions/iej5xqn2/DistantHorizons-2.3.6-b-1.21.8-fabric-neoforge.jar";
                            sha512 = "VsfMKbxXB1JSVzIgzqsB/BpGl8xjYexC+Wy/tBjIexm8znPiUqR9fd4I4SbFbQ35l4iWSENZPD+I/YyJOOfyjw==";
                        };
                        fabric-api = pkgs.fetchurl {
                            url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/RMahJx2I/fabric-api-0.136.0+1.21.8.jar";
                            sha512 = "qGgBysjioUxSoTcFpkdVJcmt4/O+8FORTczl9czeOFQSPFRK7KbPVrdaGR9uNZobm9M7MU8HYveDo6oblLpX6A==";
                        };
                    }
                );

                plugins = pkgs.linkFarmFromDrvs "plugins" [
                    (pkgs.fetchurl {
                        url = "https://cdn.modrinth.com/data/IjY7seTG/versions/NudYHdRi/DistantHorizonsSupport-0.11.0-SNAPSHOT.jar";
                        sha512 = "hD1jT9fa17Vryoq8rhUl/5KG4QW7g2rlHoaWK1geVTh23Oly0ekVSZuq/oGJR9a+AWmLARma9aJQdsdAyjkvSw==";
                    })
                ];
            };
        };
    };
}