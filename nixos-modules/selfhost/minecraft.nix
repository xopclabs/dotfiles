{ config, lib, pkgs, inputs, ... }:

with lib;
let
    cfg = config.homelab.minecraft;

    fetchMod = { url, sha512 }: pkgs.fetchurl { inherit url sha512; };

    # Aikar-style G1 flags, without options Java 25 removed
    # (G1ConcRSHotCardLimit, G1ConcRefinementServiceIntervalMillis).
    aikarJvmOpts = concatStringsSep " " [
        "-Xms4G"
        "-Xmx8G"
        "-XX:+UnlockExperimentalVMOptions"
        "-XX:+UnlockDiagnosticVMOptions"
        "-XX:+AlwaysActAsServerClassMachine"
        "-XX:+AlwaysPreTouch"
        "-XX:+DisableExplicitGC"
        "-XX:+UseNUMA"
        "-XX:NmethodSweepActivity=1"
        "-XX:ReservedCodeCacheSize=400M"
        "-XX:NonNMethodCodeHeapSize=12M"
        "-XX:ProfiledCodeHeapSize=194M"
        "-XX:NonProfiledCodeHeapSize=194M"
        "-XX:-DontCompileHugeMethods"
        "-XX:MaxNodeLimit=240000"
        "-XX:NodeLimitFudgeFactor=8000"
        "-XX:+UseVectorCmov"
        "-XX:+PerfDisableSharedMem"
        "-XX:+UseFastUnorderedTimeStamps"
        "-XX:+UseCriticalJavaThreadPriority"
        "-XX:ThreadPriorityPolicy=1"
        "-XX:+UseG1GC"
        "-XX:MaxGCPauseMillis=130"
        "-XX:G1NewSizePercent=28"
        "-XX:G1HeapRegionSize=16M"
        "-XX:G1ReservePercent=20"
        "-XX:G1MixedGCCountTarget=3"
        "-XX:InitiatingHeapOccupancyPercent=10"
        "-XX:G1MixedGCLiveThresholdPercent=90"
        "-XX:G1RSetUpdatingPauseTimePercent=0"
        "-XX:SurvivorRatio=32"
        "-XX:MaxTenuringThreshold=1"
        "-XX:G1SATBBufferEnqueueingThresholdPercent=30"
        "-XX:G1ConcMarkStepDurationMillis=5"
    ];

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
            autoStart = mkOption {
                type = types.bool;
                default = true;
                description = "Start the Distant Horizons server on boot";
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
                autoStart = cfg.distantHorizons.autoStart;
                # nix-minecraft's fabric wrapper still picks pkgs.jre_headless (21) unless overridden.
                package = pkgs.fabricServers.fabric-26_2.override {
                    jre_headless = pkgs.jdk25;
                };

                jvmOpts = aikarJvmOpts;

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
                            fabric-api = fetchMod {
                                url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/vmQp7ixA/fabric-api-0.157.0%2B26.2.jar";
                                sha512 = "sha512-Tr7EifKyzmIevrstG36XFLb9KI69tOKH12fN5XYSzx09HU9R2vfn7JVB+hRt9r3kl4q5iiljfO1tm8LzxCF2UA==";
                            };
                            lithium = fetchMod {
                                url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/f7vZ0VWU/lithium-fabric-0.25.3%2Bmc26.2.jar";
                                sha512 = "sha512-FItjjzxiKfuvSHEgojRKCvXkEaWqZTPV25112gqMDYME9j60zKE/TQOyybTCPVWd10wdgyQi74owh70AXmKovQ==";
                            };
                            ferritecore = fetchMod {
                                url = "https://cdn.modrinth.com/data/uXXizFIs/versions/d5ddUdiB/ferritecore-9.0.0-fabric.jar";
                                sha512 = "sha512-2B+pfhF4TBnUL4nC9DODHQB2A91xk87kX6F35KapxSs4SxmFhuBKD39jzZlv7XEzIleL3pqNtX4RiIVK5cvlhA==";
                            };
                            c2me = fetchMod {
                                url = "https://cdn.modrinth.com/data/VSNURh3q/versions/sOfMfJPD/c2me-fabric-mc26.2-0.4.2-alpha.0.41.jar";
                                sha512 = "sha512-ZJp+hmu/7SCZwSIoxJr7dqhQwPCHumZAx+c8wiSquSGpKq/QeX8pEZrFJjLEEpkZJNfqy5ZKjAuGT/Nj8FeYAQ==";
                            };
                            skin-restorer = fetchMod {
                                url = "https://cdn.modrinth.com/data/ghrZDhGW/versions/aXzPUPsr/skinrestorer-2.10.0%2B26.1-fabric.jar";
                                sha512 = "sha512-gujMop2ylOdkaOT/94COjkDohmxovrn7Z8gqnnyri3fc/0TKbzLuLdvmE5BKi45SleGJiApZDeAAIq7Iy6Qk8g==";
                            };
                            sortitout = fetchMod {
                                url = "https://cdn.modrinth.com/data/jcOSOvm1/versions/pEmbfGPI/sort_it_out-fabric-1.5.0%2B26.2.x.jar";
                                sha512 = "sha512-6DN0qq0QuUeYIjNmaAmsQk5R7MPR5Guv08UrmI5L60e+in0I2cw3nNZXFNvq4LoGvGhVJv82zaN9b9v5JODMkA==";
                            };
                            architectury-api = fetchMod {
                                url = "https://cdn.modrinth.com/data/lhGA9TYQ/versions/1yQC4VvP/architectury-fabric-21.0.7.jar";
                                sha512 = "sha512-3v/K1zuPc9YR2OQ92tOzgOeJa6U+S082YKuHe5xLogVh5JiIixdFayuIGfuQLiBwdgYTzm/snh8QgpkAFOkt1A==";
                            };
                            jamlib = fetchMod {
                                url = "https://cdn.modrinth.com/data/IYY9Siz8/versions/4KQpfS7o/jamlib-fabric-2.3.1%2B26.2.x.jar";
                                sha512 = "sha512-nAg9BknVpmsAfHThYeyOcJSAi0dd2jsiV2CI88Wv+yy5KcT3YAsoDyOogaJYDdvFXAUEmDgU6vVy0aoQBoehAw==";
                            };
                            cloth-config = fetchMod {
                                url = "https://cdn.modrinth.com/data/9s6osm5g/versions/Nv3xnWXd/cloth-config-26.2.155.jar";
                                sha512 = "sha512-N7HkAvDfWjg2VuIaOO4YzdFctLo/ti++uoLvS5WaRHn8MnGKwNnRVKfZEExfcxW/pn2+ztC4/yQLgDnUhI1d8Q==";
                            };
                            sodium = fetchMod {
                                url = "https://cdn.modrinth.com/data/AANobbMI/versions/a9YZH3ip/sodium-fabric-0.9.2-alpha.4%2Bmc26.2.jar";
                                sha512 = "sha512-LHpUhhbmqezJoKrrPxkr91vkJPqWXnrCSOlYU1MwzO6AWQJsw7q5/EgeCQVURtaEvAfFe8gvkfuWalLXFCvkcg==";
                            };
                            voxy = fetchMod {
                                url = "https://cdn.modrinth.com/data/fxxUqruK/versions/zZX86mbc/voxy-0.2.18-beta.jar";
                                sha512 = "sha512-JgXZJVzE5y5AHPjeKZrQHCGppIKNT40rbsT2PqWf0hxNKckiVcUJefhIzMtAV/C2h/s8nIf6TA3WL2hUDk2Euw==";
                            };
                            voxy-worldgen = fetchMod {
                                url = "https://cdn.modrinth.com/data/xT0lnNE9/versions/fZooaCeC/Voxy%20World%20Gen%20V2-fabric-26.2-2.4.3.jar";
                                sha512 = "sha512-wuZBqxxjEPxn/5T37cUttBp8s4LHNtK/LiMVa+Me2Mh42kITClxvc3WsDv2Y+ZhA8HkyPzSLK/b8s32NMp7z8w==";
                            };
                            voxyserver = fetchMod {
                                url = "https://cdn.modrinth.com/data/fNtGd1cx/versions/EsIPjK0A/VoxyServer-1.2.4-26.2.jar";
                                sha512 = "sha512-rQdhyNdStsKuBcScxOLRdWltmi7oV8HU+jbvnlUpptN2N0h2BQo2NmbM1nnW6Zslk8sNgJSujUnw8e0C49BHew==";
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
