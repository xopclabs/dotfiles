{ config, lib, pkgs, inputs, ... }:

with lib;
let
    cfg = config.homelab.minecraft;
    
    betaSrc = pkgs.fetchurl {
        url = "https://meta.babric.glass-launcher.net/v2/versions/loader/b1.7.3/0.17.3/1.0.0-babric.2/server/jar";
        sha512 = "sha512-ePXHsEkF3qjfb0Y1gY7MxOvuJ8rupT8mIgnw8LIXwayiuiqTENHTwWUCMvajjXo0NhdFpdqgJKbbAcYbNGSH5A==";
    };
    baseVanilla = pkgs.vanillaServers.vanilla;
    beta173Pkg = (
        baseVanilla.overrideAttrs (_: {
            pname = "vanilla-beta-1_7_3";
            version = "b1.7.3";
            src = betaSrc;
        })
    );
in
{
    options.homelab.minecraft = {
        enable = mkEnableOption "Minecraft servers";
        openFirewall = mkOption {
            type = types.bool;
            default = true;
            description = "Open firewall for Minecraft servers";
        };

        distantHorizons = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable the Distant Horizons server";
            };
            backup = {
                enable = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Enable borgbase backup for the Distant Horizons server";
                };
                repo = mkOption {
                    type = types.str;
                    default = "";
                    description = "Borgbase repository URL for Distant Horizons backups";
                };
            };
        };
        
        beta = {
            enable = mkOption {
                type = types.bool;
                default = false;
                description = "Enable the Beta 1.7.3 server";
            };
            
            port = mkOption {
                type = types.port;
                default = 25575;
                description = "Server port for Beta server";
            };
            backup = {
                enable = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Enable borgbase backup for the Beta server";
                };
                repo = mkOption {
                    type = types.str;
                    default = "";
                    description = "Borgbase repository URL for Beta backups";
                };
            };
        };
    };
    
    imports = [ inputs.nix-minecraft.nixosModules.minecraft-servers ];

    config = mkIf cfg.enable {
        nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];

        users.groups.minecraft.members = [ "homelab" ];

        sops.secrets."minecraft/ops.json" = {
            sopsFile = ../../secrets/hosts/${config.metadata.hostName}.yaml;
            owner = "minecraft";
            group = "minecraft";
            mode = "0660";
        };
        sops.secrets."minecraft/whitelist.json" = {
            sopsFile = ../../secrets/hosts/${config.metadata.hostName}.yaml;
            owner = "minecraft";
            group = "minecraft";
            mode = "0660";
        };

        services.minecraft-servers = {
            enable = true;
            eula = true;
            openFirewall = cfg.openFirewall;

            servers.distant-horizons = mkIf cfg.distantHorizons.enable {
                enable = true;
                autoStart = true;
                package = pkgs.fabricServers.fabric-1_21_11;

                jvmOpts = "-Xms4G -Xmx8G -XX:+UnlockExperimentalVMOptions -XX:+UnlockDiagnosticVMOptions -XX:+AlwaysActAsServerClassMachine -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+UseNUMA -XX:NmethodSweepActivity=1 -XX:ReservedCodeCacheSize=400M -XX:NonNMethodCodeHeapSize=12M -XX:ProfiledCodeHeapSize=194M -XX:NonProfiledCodeHeapSize=194M -XX:-DontCompileHugeMethods -XX:MaxNodeLimit=240000 -XX:NodeLimitFudgeFactor=8000 -XX:+UseVectorCmov -XX:+PerfDisableSharedMem -XX:+UseFastUnorderedTimeStamps -XX:+UseCriticalJavaThreadPriority -XX:ThreadPriorityPolicy=1 -XX:+UseG1GC -XX:MaxGCPauseMillis=130 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=28 -XX:G1HeapRegionSize=16M -XX:G1ReservePercent=20 -XX:G1MixedGCCountTarget=3 -XX:InitiatingHeapOccupancyPercent=10 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=0 -XX:SurvivorRatio=32 -XX:MaxTenuringThreshold=1 -XX:G1SATBBufferEnqueueingThresholdPercent=30 -XX:G1ConcMarkStepDurationMillis=5 -XX:G1ConcRSHotCardLimit=16 -XX:G1ConcRefinementServiceIntervalMillis=150";

                serverProperties = {
                    difficulty = "hard";
                    hardcore = false;
                    gamemode = 0;
                    spawn-monsters = true;
                    level-seed = "";
                    max-players = 2;
                    motd = "socorro...";
                    online-mode = false;
                    pvp = true;
                    view-distance = 16;
                    simulation-distance = 16;
                    spawn-protection = 16;
                    white-list = true;
                };

                files = {
                    "ops.json" = config.sops.secrets."minecraft/ops.json".path;
                    "whitelist.json" = config.sops.secrets."minecraft/whitelist.json".path;
                };
                symlinks = {
                    mods = pkgs.linkFarmFromDrvs "mods" (
                        builtins.attrValues {
                            fabric-api = pkgs.fetchurl {
                                url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/DdVHbeR1/fabric-api-0.141.1+1.21.11.jar";
                                sha512 = "sha512-GFtF3L4ikjA538mYyQ1scZZhDPRCwoS6P7x+4mEWuKIDZ7+TECT7pmu6B7xDePy7i5FCwbHBS6QgDVClq6AzLw==";
                            };
                            distant-horizons = pkgs.fetchurl {
                                url = "https://cdn.modrinth.com/data/uCdwusMi/versions/GT3Bm3GN/DistantHorizons-2.4.5-b-1.21.11-fabric-neoforge.jar";
                                sha512 = "sha512-qfZz+sH29VS3OUFoy+cm8aFesrvvG2WzyZeYU6+N5wvxOkV8iOvcMLlVoHHVGehsYxzb8d05zat8c7nC1/Fl4Q==";
                            };
                            c2me = pkgs.fetchurl {
                                url = "https://cdn.modrinth.com/data/VSNURh3q/versions/olrVZpJd/c2me-fabric-mc1.21.11-0.3.6.0.0.jar";
                                sha512 = "sha512-ybERAFcvtxwwgP8RsBFGdiToATuZQqreCaXHfrYrMolme61wUB3eqPNd6wpdJohLefdtTtES0yNCRxynOEt4ig==";
                            };
                            lithium = pkgs.fetchurl {
                                url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/gl30uZvp/lithium-fabric-0.21.2+mc1.21.11.jar";
                                sha512 = "sha512-lGJVEAE+DarxwuK22KRjyTL/YiD5G6WwzV+GhlghXwRtlNB7NGVmD1dsTcJ6WqGD373ByTA/EYlLWyWh3Gw7tg==";
                            };
                            ferritecore = pkgs.fetchurl {
                                url = "https://cdn.modrinth.com/data/uXXizFIs/versions/eRLwt73x/ferritecore-8.0.3-fabric.jar";
                                sha512 = "sha512-vmAFQ+SZtZKG+UCfRkl1cK3FGTmuY+qhKsKeZ3jaJ9jHxs0LM0DYvMocyZzmF3mxqPUrmQ+eTpqTqpxkgpBSMQ==";
                            };
                            skin-restorer = pkgs.fetchurl {
                                url = "https://cdn.modrinth.com/data/ghrZDhGW/versions/ZIKgsH8x/skinrestorer-2.5.0+1.21.11-fabric.jar";
                                sha512 = "sha512-v9XWeFK7jl11eu6GV+3RuLYmjVJkYiJDNzE7HAHcXbWB5EukEIXKpJYQOekOc6L6DgFFFDUeNWaty03h/jCRtw==";
                            };

                            itemframes = pkgs.fetchurl {
                                url = "https://cdn.modrinth.com/data/aONWPSiA/versions/TlQcxFP0/easeon.ss.chestpeek.teron.fabric-1.1.0.1+1.21.11.jar";
                                sha512 = "sha512-Wo0/tHLyLX7Md/XsMaRVz7sd8uwY/1LNTKHfWGH9cRtpc1G2JQ9SML400+7TZyi7q+7yNgUGKAYX61JGdHmcZA==";
                            };
                            easeon-ss-core = pkgs.fetchurl {
                                url = "https://cdn.modrinth.com/data/bUCIzqY5/versions/dRR7zWnE/easeon.ss.core.teron.fabric-1.1.30.0+1.21.11.jar";
                                sha512 = "sha512-/fD8hjtkiDrtM5knLgKPRBgK8X6XwTmfucjln28HY43TyoO7CtH9wnvCmQSAEHfDevbnkF9IA+sUe3XGOdpnjQ==";
                            };

                            sortitout = pkgs.fetchurl {
                                url = "https://cdn.modrinth.com/data/jcOSOvm1/versions/idY3jZnE/sort_it_out-fabric-1.2.0+1.21.11.jar";
                                sha512 = "sha512-WnL1VHCnCQMVtQRPzbTVWjky5uzdi54b9pJAnRNjISkeFBPuzZsbBFPU2fSvS4zmTHG7vzwcA6RTc1TeoE1wBw==";
                            };
                            architectury-api = pkgs.fetchurl {
                                url = "https://cdn.modrinth.com/data/lhGA9TYQ/versions/uNdfrcQ8/architectury-19.0.1-fabric.jar";
                                sha512 = "sha512-fKUyhEoO09NehRXhPR6E+OrfzqrpMoG3mta02sJT9GNOPfzHWS+VQ4cd7BF+GjCSwZa6Xq4zc1Fi3iI74Z3ErQ==";
                            };
                            iamlib = pkgs.fetchurl {
                                url = "https://cdn.modrinth.com/data/IYY9Siz8/versions/SUWZN0xp/jamlib-fabric-1.3.5+1.21.11.jar";
                                sha512 = "sha512-E1X6/tEfwnHiXJTXmzye9xzdQkMXUFLS5agG6shnKOLV/tm5ZEBKJX2uLnDJuEkAGftDw0V3YFlxyKwPIsClUQ==";
                            };
                        }
                    );
                };
            };

            servers.beta = mkIf cfg.beta.enable {
                enable = true;
                autoStart = false;
                package = beta173Pkg;

                jvmOpts = "-Xms512M -Xmx1G -XX:+UseG1GC";

                serverProperties = {
                    level-name = "world";
                    allow-nether = true;
                    view-distance = 10;
                    spawn-monsters = true;
                    spawn-animals = true;
                    pvp = true;
                    white-list = false;
                    online-mode = false;
                    max-players = 2;
                    server-port = cfg.beta.port;
                };
            };
        };

        # Borgbase backups for minecraft servers
        homelab.borgbackup.jobs = mkMerge [
            (mkIf (cfg.distantHorizons.enable && cfg.distantHorizons.backup.enable) {
                minecraft-distant-horizons-borgbase = {
                    paths = [ "/srv/minecraft/distant-horizons" ];
                    repo = cfg.distantHorizons.backup.repo;
                    schedule = "daily";
                    encryption.mode = "repokey-blake2";
                    prune.keep = { daily = 7; weekly = 4; };
                };
            })
            (mkIf (cfg.beta.enable && cfg.beta.backup.enable) {
                minecraft-beta-borgbase = {
                    paths = [ "/srv/minecraft/beta" ];
                    repo = cfg.beta.backup.repo;
                    schedule = "daily";
                    encryption.mode = "repokey-blake2";
                    prune.keep = { daily = 7; weekly = 4; };
                };
            })
        ];
    };
}

