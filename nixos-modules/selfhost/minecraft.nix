{ config, lib, pkgs, inputs, ... }:

with lib;
let
    cfg = config.homelab.minecraft;
    bluemapCfg = cfg.distantHorizons.bluemap;

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

    minecraftCli = pkgs.writeShellApplication {
        name = "minecraft";
        runtimeInputs = [ pkgs.tmux pkgs.systemd pkgs.coreutils ];
        text = ''
            PATH="/run/wrappers/bin:$PATH"

            run_dir="/run/minecraft"
            server="distant-horizons"
            unit="minecraft-server-$server"

            usage() {
                echo "Usage: minecraft [-s server] attach"
                echo "       minecraft [-s server] send <command...>"
                echo "       minecraft [-s server] start|stop|restart|status"
            }

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -s|--server)
                        server="$2"
                        unit="minecraft-server-$server"
                        shift 2
                        ;;
                    -h|--help)
                        usage
                        exit 0
                        ;;
                    *)
                        break
                        ;;
                esac
            done

            if [[ $# -lt 1 ]]; then
                usage
                exit 1
            fi

            action="$1"
            shift
            socket="$run_dir/$server.sock"

            require_socket() {
                if [[ ! -S "$socket" && ! -e "$socket" ]]; then
                    echo "minecraft: no console socket at $socket" >&2
                    echo "Is the '$server' server running?" >&2
                    exit 1
                fi
            }

            capture_pane() {
                tmux -S "$socket" capture-pane -p -J -S -
            }

            case "$action" in
                attach)
                    require_socket
                    exec tmux -S "$socket" attach
                    ;;
                send)
                    require_socket
                    if [[ $# -lt 1 ]]; then
                        echo "minecraft send: missing command" >&2
                        exit 1
                    fi
                    before=$(capture_pane)
                    tmux -S "$socket" send-keys -l -- "$*"
                    tmux -S "$socket" send-keys Enter

                    after="$before"
                    stable=0
                    i=0
                    while [[ $i -lt 40 ]]; do
                        sleep 0.2
                        now=$(capture_pane)
                        if [[ "$now" != "$after" ]]; then
                            after="$now"
                            stable=0
                        else
                            stable=$((stable + 1))
                            if [[ "$after" != "$before" && $stable -ge 2 ]]; then
                                break
                            fi
                        fi
                        i=$((i + 1))
                    done

                    if [[ "$after" == "$before" ]]; then
                        echo "minecraft send: no console output" >&2
                        exit 0
                    fi
                    if [[ "$after" == "$before"* ]]; then
                        printf '%s\n' "''${after#"$before"}"
                    else
                        printf '%s\n' "$after" | tail -n 40
                    fi
                    ;;
                start|stop|restart)
                    exec sudo systemctl "$action" "$unit"
                    ;;
                status)
                    exec systemctl --no-pager --full status "$unit"
                    ;;
                *)
                    usage
                    exit 1
                    ;;
            esac
        '';
    };
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
            bluemap = {
                enable = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Enable BlueMap web map for generated chunks";
                };
                subdomain = mkOption {
                    type = types.str;
                    default = "bluemap.vm.local";
                    description = "Subdomain for the BlueMap web UI";
                };
                address = mkOption {
                    type = types.str;
                    default = "127.0.0.1";
                    description = "Address BlueMap's webserver binds to";
                };
                port = mkOption {
                    type = types.port;
                    default = 8100;
                    description = "Port for BlueMap's integrated webserver";
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
        environment.systemPackages = [ minecraftCli ];

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
                } // optionalAttrs bluemapCfg.enable {
                    "config/bluemap/core.conf" = pkgs.writeText "bluemap-core.conf" ''
                        accept-download: true
                        data: "bluemap"
                        render-thread-count: 1
                        render-thread-priority: 2
                        update-cooldown: 60
                        full-update-interval: 1440
                        scan-for-mod-resources: true
                    '';
                    "config/bluemap/webserver.conf" = pkgs.writeText "bluemap-webserver.conf" ''
                        enabled: true
                        webroot: "bluemap/web"
                        port: ${toString bluemapCfg.port}
                        ip: "${bluemapCfg.address}"
                    '';
                };
                symlinks = {
                    mods = pkgs.linkFarmFromDrvs "mods" (
                        builtins.attrValues ({
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
                        } // optionalAttrs bluemapCfg.enable {
                            bluemap = fetchMod {
                                url = "https://cdn.modrinth.com/data/swbUV1cr/versions/VTvifNPN/bluemap-5.22-fabric.jar";
                                sha512 = "sha512-7Fl99+l08fKLqhUyU3NEKWjJZDoVem0mJ81cNviEHDAj8sCAI9IDvPp+DlG85p1GI7pxK6u4Tac71A8ODH9NvQ==";
                            };
                        })
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

        homelab.traefik.routes = mkIf (cfg.distantHorizons.enable && bluemapCfg.enable && config.homelab.traefik.enable) [
            {
                name = "bluemap";
                subdomain = bluemapCfg.subdomain;
                backendUrl = "http://${bluemapCfg.address}:${toString bluemapCfg.port}";
                serversTransport = "defaultTransport";
            }
        ];

        homelab.glance.services = mkIf (cfg.distantHorizons.enable && bluemapCfg.enable && config.homelab.glance.enable) [
            {
                title = "BlueMap";
                subdomain = bluemapCfg.subdomain;
                icon = "mdi:map";
                group = "Services";
            }
        ];

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
