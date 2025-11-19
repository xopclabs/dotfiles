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
            
        distantHorizons = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable the Distant Horizons server";
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
            openFirewall = true;

            servers.distant-horizons = mkIf cfg.distantHorizons.enable {
                enable = true;
                autoStart = true;
                package = pkgs.fabricServers.fabric-1_21_10;

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
                                url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/lxeiLRwe/fabric-api-0.136.0+1.21.10.jar";
                                sha512 = "sha512-1q1a/rV9xtvhepSJkPyEQfu8E6dIgUpxVmQE2Rk4Tfi9er69pSpYpB62Y3Coa4xPkQtkczsTWUbs1H5TJxMQtQ==";
                            };
                            distant-horizons = pkgs.fetchurl {
                                url = "https://cdn.modrinth.com/data/uCdwusMi/versions/9Y10ZuWP/DistantHorizons-2.3.6-b-1.21.10-fabric-neoforge.jar";
                                sha512 = "sha512-Gxtwt+xikNFSpfn6Py5o6niV9AfFYbVukauj/a3vJ3zSWYeWdhmNZIHcx2oib/GqhXwBrpxBvj6WO1lUYHSh/A==";
                            };
                            c2me = pkgs.fetchurl {
                                url = "https://cdn.modrinth.com/data/VSNURh3q/versions/eY3dbqLu/c2me-fabric-mc1.21.10-0.3.5.0.0.jar";
                                sha512 = "sha512-o0IrdYmak1WqExKGUe0oFf+D/2mMTCKpTqfydcZWr/JHRACFpH3iA1P/VEaVdMhK3JtCjC6WOoCjxmV/uEmCXQ==";
                            };
                            lithium = pkgs.fetchurl {
                                url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/oGKQMdyZ/lithium-fabric-0.20.0+mc1.21.10.jar";
                                sha512 = "sha512-dVwOD8f284rE2TbMYCPR3Obs/Y1r3CxUTCo8PW0E8NhdtTcioIn6i+cq4y/BJ+h/WUZ5O6botPLCli7TDTM+0g==";
                            };
                            ferritecore = pkgs.fetchurl {
                                url = "https://cdn.modrinth.com/data/uXXizFIs/versions/CtMpt7Jr/ferritecore-8.0.0-fabric.jar";
                                sha512 = "sha512-ExuC0dNm8JZkNb/LOMNi1gTWjs8wwQbTGmJhv8hoyjqCQluz+uuqLl6hfY7tXJKEOBDrLfR5Dy+LHmwb3Jt3RQ==";
                            };
                            appleskin = pkgs.fetchurl {
                                url = "https://cdn.modrinth.com/data/EsAfCjCV/versions/8sbiz1lS/appleskin-fabric-mc1.21.9-3.0.7.jar";
                                sha512 = "sha512-edDQtKCRQM23z3SxzXFVQUfGBki+tIXKZHsUkXThcWYOxWGtMp2li3i13kOZCbGA4oe0s4vwaKz8ogZmEA9FhA==";
                            };
                            ping-wheel = pkgs.fetchurl {
                                url = "https://cdn.modrinth.com/data/QQXAdCzh/versions/2qmGuLd3/Ping-Wheel-1.12.0-fabric-1.21.10.jar";
                                sha512 = "sha512-0DJVA3Tgz1dxFYXHfoCW0Nd3vvTcwMyZw4QZApeICXRZmDb5YlC6GCrKsk+TsJ7/HTtMIj8+pOzdaOGT/AUrnQ==";
                            };
                            skin-restorer = pkgs.fetchurl {
                                url = "https://cdn.modrinth.com/data/ghrZDhGW/versions/MKWfnXfO/skinrestorer-2.4.3+1.21.9-fabric.jar";
                                sha512 = "sha512-o3cTNGdwe4iDRkJmCjpCE3rLir+/gNvKh1CLcBqkrKPp0XOO8/wJhifHYOav3qMvzfilg1lC0pHvBkDz7zZnxQ==";
                            };
                        }
                    );
                };
            };

            servers.beta = mkIf cfg.beta.enable {
                enable = true;
                autoStart = true;
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
    };
}

