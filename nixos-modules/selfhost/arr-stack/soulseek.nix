{ config, lib, pkgs, ... }:

with lib;
let
    sk = config.homelab.arr-stack.soulseek;
    arrCfg = config.homelab.arr-stack;
    arrProxyEnvFile = "/run/arr-proxy.env";
    ociBackend = config.virtualisation.oci-containers.backend;

    sl = sk.slskd;
    sa = sk.soularr;
    sy = sk.soulsync;

    boolToIni = b: if b then "True" else "False";

    configTemplate = pkgs.writeText "soularr-config.ini" ''
        [Lidarr]
        api_key = __LIDARR_API_KEY__
        host_url = __LIDARR_HOST_URL__
        download_dir = ${sl.downloadsDir}
        disable_sync = ${boolToIni sa.lidarr.disableSync}

        [Slskd]
        api_key = __SLSKD_API_KEY__
        host_url = http://127.0.0.1:${toString sl.port}
        url_base = /
        download_dir = /downloads
        delete_searches = ${boolToIni sa.slskd.deleteSearches}
        stalled_timeout = ${toString sa.slskd.stalledTimeout}

        [Release Settings]
        use_most_common_tracknum = ${boolToIni sa.releaseSettings.useMostCommonTracknum}
        allow_multi_disc = ${boolToIni sa.releaseSettings.allowMultiDisc}
        accepted_countries = ${concatStringsSep "," sa.releaseSettings.acceptedCountries}
        accepted_formats = ${concatStringsSep "," sa.releaseSettings.acceptedFormats}

        [Search Settings]
        search_timeout = ${toString sa.searchSettings.searchTimeout}
        maximum_peer_queue = ${toString sa.searchSettings.maximumPeerQueue}
        minimum_peer_upload_speed = ${toString sa.searchSettings.minimumPeerUploadSpeed}
        minimum_filename_match_ratio = ${toString sa.searchSettings.minimumFilenameMatchRatio}
        allowed_filetypes = ${concatStringsSep "," sa.searchSettings.allowedFiletypes}
        ignored_users = ${concatStringsSep "," sa.searchSettings.ignoredUsers}
        search_for_tracks = ${boolToIni sa.searchSettings.searchForTracks}
        album_prepend_artist = ${boolToIni sa.searchSettings.albumPrependArtist}
        track_prepend_artist = ${boolToIni sa.searchSettings.trackPrependArtist}
        search_type = ${sa.searchSettings.searchType}
        number_of_albums_to_grab = ${toString sa.searchSettings.numberOfAlbumsToGrab}
        remove_wanted_on_failure = ${boolToIni sa.searchSettings.removeWantedOnFailure}
        title_blacklist = ${concatStringsSep "," sa.searchSettings.titleBlacklist}
        search_source = ${sa.searchSettings.searchSource}

        [Logging]
        level = ${sa.logging.level}
        format = ${sa.logging.format}
        datefmt = ${sa.logging.datefmt}
    '';
in
{
    options.homelab.arr-stack.soulseek = {
        slskd = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = ''
                  Slskd (Soulseek daemon): downloads, shares, and API for Soularr / SoulSync.
                '';
            };

            subdomain = mkOption {
                type = types.str;
                description = "Subdomain for the Slskd web UI (Traefik).";
            };

            port = mkOption {
                type = types.port;
                default = 5530;
                description = "Slskd web UI and API port.";
            };

            openFirewall = mkEnableOption "Soulseek listen port in the firewall";

            dataDir = mkOption {
                type = types.path;
                default = "/var/lib/soulseek/slskd";
                description = "Directory for Slskd-related host state (e.g. `slskd-api-key`).";
            };

            downloadsDir = mkOption {
                type = types.path;
                default = "/mnt/raid_pool/shared/downloads/soulseek/downloads";
                description = "Completed downloads (shared with Soularr, SoulSync, Lidarr).";
            };

            incompleteDir = mkOption {
                type = types.path;
                default = "/mnt/raid_pool/shared/downloads/soulseek/incomplete";
                description = "In-progress Slskd downloads.";
            };

            shareDirectories = mkOption {
                type = types.listOf types.str;
                default = [ config.metadata.selfhost.storage.media.musicDir ];
                description = "Library paths to advertise on the Soulseek network.";
            };
        };

        soularr = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = ''
                  Soularr ([`mrusse08/soularr`](https://github.com/mrusse08/Soularr)): Lidarr automation via Slskd.
                  Requires `soulseek.slskd.enable`.
                '';
            };

            dataDir = mkOption {
                type = types.path;
                default = "/var/lib/soularr";
                description = "Soularr container state (`config.ini`, etc.).";
            };

            scriptInterval = mkOption {
                type = types.int;
                default = 300;
                description = "How often Soularr runs (seconds).";
            };

            extraOptions = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Extra flags for the Soularr container runtime.";
            };

            lidarr = {
                disableSync = mkOption {
                    type = types.bool;
                    default = false;
                    description = "If true, Lidarr will not auto-import from the Slskd download folder.";
                };
            };

            releaseSettings = {
                useMostCommonTracknum = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Prefer releases whose track count matches the album.";
                };

                allowMultiDisc = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Allow multi-disc releases.";
                };

                acceptedCountries = mkOption {
                    type = types.listOf types.str;
                    default = [ "Europe" "Japan" "United Kingdom" "United States" "[Worldwide]" "Australia" "Canada" ];
                    description = "Accepted MusicBrainz release countries.";
                };

                acceptedFormats = mkOption {
                    type = types.listOf types.str;
                    default = [ "CD" "Digital Media" "Vinyl" ];
                    description = "Accepted MusicBrainz release formats.";
                };
            };

            searchSettings = {
                searchTimeout = mkOption {
                    type = types.int;
                    default = 5000;
                    description = "Search timeout (ms).";
                };

                maximumPeerQueue = mkOption {
                    type = types.int;
                    default = 50;
                    description = "Maximum Soulseek peer queue length.";
                };

                minimumPeerUploadSpeed = mkOption {
                    type = types.int;
                    default = 0;
                    description = "Minimum peer upload speed (bit/s); 0 = no limit.";
                };

                minimumFilenameMatchRatio = mkOption {
                    type = types.float;
                    default = 0.8;
                    description = "Minimum filename match confidence vs Lidarr track.";
                };

                allowedFiletypes = mkOption {
                    type = types.listOf types.str;
                    default = [ "flac 16/44.1" "flac 24/48" "flac" "mp3 320" ];
                    description = "Preferred formats (ordered).";
                };

                ignoredUsers = mkOption {
                    type = types.listOf types.str;
                    default = [ ];
                    description = "Soulseek usernames to ignore.";
                };

                searchForTracks = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Search individual tracks as well as albums.";
                };

                albumPrependArtist = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Prepend artist to album search queries.";
                };

                trackPrependArtist = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Prepend artist to track search queries.";
                };

                searchType = mkOption {
                    type = types.enum [ "all" "incrementing_page" "first_page" ];
                    default = "incrementing_page";
                    description = "Soulseek search pagination mode.";
                };

                numberOfAlbumsToGrab = mkOption {
                    type = types.int;
                    default = 10;
                    description = "Albums to process per Soularr run.";
                };

                removeWantedOnFailure = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Unmonitor album on failure (`failure_list.txt`).";
                };

                titleBlacklist = mkOption {
                    type = types.listOf types.str;
                    default = [ ];
                    description = "Case-insensitive title blacklist.";
                };

                searchSource = mkOption {
                    type = types.enum [ "missing" "cutoff_unmet" ];
                    default = "missing";
                    description = "Lidarr wanted source.";
                };
            };

            logging = {
                level = mkOption {
                    type = types.enum [ "DEBUG" "INFO" "WARNING" "ERROR" "CRITICAL" ];
                    default = "INFO";
                    description = "Python log level.";
                };

                format = mkOption {
                    type = types.str;
                    default = "[%(levelname)s|%(module)s|L%(lineno)d] %(asctime)s: %(message)s";
                    description = "Python log format.";
                };

                datefmt = mkOption {
                    type = types.str;
                    default = "%Y-%m-%dT%H:%M:%S%z";
                    description = "Python log date format.";
                };
            };

            slskd = {
                deleteSearches = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Delete Slskd search results after each Soularr run (`[Slskd]` in `config.ini`).";
                };

                stalledTimeout = mkOption {
                    type = types.int;
                    default = 3600;
                    description = "Max seconds to wait for stalled Slskd downloads before giving up.";
                };
            };
        };

        soulsync = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = ''
                  [SoulSync](https://github.com/Nezreka/SoulSync) (`boulderbadgedad/soulsync:latest`): discovery, downloads,
                  and media-server sync. Set `soulseek.slskd.enable` for Soulseek downloads via Slskd.
                '';
            };

            subdomain = mkOption {
                type = types.str;
                description = "Subdomain for the SoulSync web UI (Traefik).";
            };

            port = mkOption {
                type = types.port;
                default = 8008;
                description = "Web UI port (host networking). OAuth uses 8888/8889 on the host as well.";
            };

            openFirewall = mkEnableOption ''
              TCP 8008 (UI) and 8888/8889 (Spotify/Tidal OAuth callbacks). Prefer Traefik for 8008 when possible.
            '';

            proxy = mkOption {
                type = types.bool;
                default = true;
                description = "Inject `/run/arr-proxy.env` for outbound HTTP(S) via xray.";
            };

            dataDir = mkOption {
                type = types.path;
                default = "/var/lib/soulsync";
                description = "Base directory (`config/`, `logs/`, SQLite under `data/`).";
            };

            downloadsDir = mkOption {
                type = types.path;
                default = config.homelab.arr-stack.soulseek.slskd.downloadsDir;
                description = "Mounted at `/app/downloads` (usually the same tree as Slskd).";
            };

            stagingDir = mkOption {
                type = types.path;
                default = "/var/lib/soulsync/staging";
                description = "Mounted at `/app/Staging`.";
            };

            transferDir = mkOption {
                type = types.path;
                default = config.metadata.selfhost.storage.media.musicDir;
                description = "Mounted at `/app/Transfer` (organized library).";
            };

            extraOptions = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Extra container runtime flags.";
            };
        };
    };

    config = mkMerge [
        {
            assertions = [
                {
                    assertion = !(arrCfg.enable && sa.enable) || sl.enable;
                    message = "`homelab.arr-stack.soulseek.soularr.enable` requires `homelab.arr-stack.soulseek.slskd.enable`.";
                }
                {
                    assertion = !(arrCfg.enable && sa.enable) || arrCfg.lidarr.enable;
                    message = "`homelab.arr-stack.soulseek.soularr.enable` requires `homelab.arr-stack.lidarr.enable` (Soularr calls the Lidarr API).";
                }
            ];
        }

        (mkIf (arrCfg.enable && sl.enable) {
            sops.secrets."soularr/slskd-env" = {
                sopsFile = ../../../secrets/shared/selfhost.yaml;
            };

            services.slskd = {
                enable = true;
                domain = null;
                environmentFile = "/run/slskd-env";
                openFirewall = sl.openFirewall;
                group = "users";
                settings = {
                    directories.downloads = sl.downloadsDir;
                    directories.incomplete = sl.incompleteDir;
                    shares.directories = sl.shareDirectories;
                    web.port = sl.port;
                };
            };

            systemd.tmpfiles.rules = [
                "d ${sl.dataDir} 0750 ${config.metadata.user} users -"
            ];

            systemd.services.slskd = {
                after = [ "soulseek-slskd-setup.service" ];
                requires = [ "soulseek-slskd-setup.service" ];
                serviceConfig = {
                    UMask = "0002";
                    RequiresMountsFor = [
                        sl.downloadsDir
                        sl.incompleteDir
                    ];
                };
            };

            systemd.services.soulseek-slskd-setup = {
                description = "Prepare Slskd download dirs and /run/slskd-env";
                wantedBy = [ "multi-user.target" ];
                before = [ "slskd.service" ];
                serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                    RequiresMountsFor = [
                        sl.downloadsDir
                        sl.incompleteDir
                    ];
                };
                script = ''
                    ${pkgs.coreutils}/bin/mkdir -p ${sl.downloadsDir} ${sl.incompleteDir} ${sl.dataDir}
                    ${pkgs.coreutils}/bin/chown slskd:users ${sl.downloadsDir} ${sl.incompleteDir}
                    ${pkgs.coreutils}/bin/chmod 2775 ${sl.downloadsDir} ${sl.incompleteDir}
                    ${pkgs.acl}/bin/setfacl -m g:users:rwx ${sl.downloadsDir} ${sl.incompleteDir}
                    ${pkgs.acl}/bin/setfacl -d -m g:users:rwx ${sl.downloadsDir} ${sl.incompleteDir}

                    KEY_FILE="${sl.dataDir}/slskd-api-key"
                    LEGACY_KEY="${sa.dataDir}/slskd-api-key"
                    if [ ! -f "$KEY_FILE" ] && [ -f "$LEGACY_KEY" ]; then
                        ${pkgs.coreutils}/bin/cp "$LEGACY_KEY" "$KEY_FILE"
                        chmod 600 "$KEY_FILE"
                    fi
                    if [ ! -f "$KEY_FILE" ]; then
                        ${pkgs.openssl}/bin/openssl rand -hex 16 > "$KEY_FILE"
                        chmod 600 "$KEY_FILE"
                    fi
                    SLSKD_KEY=$(cat "$KEY_FILE")

                    cat ${config.sops.secrets."soularr/slskd-env".path} > /run/slskd-env
                    echo "SLSKD_API_KEY=$SLSKD_KEY" >> /run/slskd-env
                    chmod 600 /run/slskd-env
                '' + optionalString sa.enable ''
                    set -a
                    source ${config.sops.secrets."traefik/env".path}
                    set +a

                    LIDARR_KEY=$(cat ${config.sops.secrets."soularr/lidarr-api-key".path})
                    LIDARR_URL="https://${arrCfg.lidarr.subdomain}.$DOMAIN"

                    ${pkgs.coreutils}/bin/mkdir -p ${sa.dataDir}
                    ${pkgs.gnused}/bin/sed \
                        -e "s|__LIDARR_API_KEY__|$LIDARR_KEY|" \
                        -e "s|__SLSKD_API_KEY__|$SLSKD_KEY|" \
                        -e "s|__LIDARR_HOST_URL__|$LIDARR_URL|" \
                        ${configTemplate} > ${sa.dataDir}/config.ini
                    chmod 640 ${sa.dataDir}/config.ini
                '';
            };

            homelab.traefik.routes = mkIf config.homelab.traefik.enable [
                {
                    name = "slskd";
                    subdomain = sl.subdomain;
                    backendUrl = "http://127.0.0.1:${toString sl.port}";
                }
            ];

            homelab.glance.services = mkIf config.homelab.glance.enable [
                {
                    title = "Soulseek";
                    subdomain = sl.subdomain;
                    icon = "mdi:bird";
                    group = "*arr";
                    priority = 5;
                }
            ];
        })

        (mkIf (arrCfg.enable && sa.enable) {
            sops.secrets."soularr/lidarr-api-key" = {
                sopsFile = ../../../secrets/shared/selfhost.yaml;
            };

            systemd.tmpfiles.rules = [
                "d ${sa.dataDir} 0750 ${config.metadata.user} users -"
            ];

            systemd.services."${ociBackend}-soularr" = {
                after = [ "slskd.service" ];
                requires = [ "slskd.service" ];
            };

            virtualisation.oci-containers.containers.soularr = {
                image = "mrusse08/soularr:latest";
                volumes = [
                    "${sl.downloadsDir}:/downloads"
                    "${sa.dataDir}:/data"
                ];
                environment = {
                    TZ = "UTC";
                    SCRIPT_INTERVAL = toString sa.scriptInterval;
                };
                extraOptions =
                    [
                        "--network=host"
                        "--pull=always"
                    ]
                    ++ sa.extraOptions;
            };
        })

        (mkIf (arrCfg.enable && sy.enable) {
            systemd.tmpfiles.rules = [
                "d ${sy.dataDir} 0750 ${config.metadata.user} users -"
                "d ${sy.dataDir}/config 0750 ${config.metadata.user} users -"
                "d ${sy.dataDir}/logs 0750 ${config.metadata.user} users -"
                "d ${sy.dataDir}/data 0750 ${config.metadata.user} users -"
                "d ${sy.stagingDir} 0750 ${config.metadata.user} users -"
            ];

            networking.firewall.allowedTCPPorts = mkIf sy.openFirewall [
                sy.port
                8888
                8889
            ];

            systemd.services."${ociBackend}-soulsync" = mkMerge [
                (mkIf sl.enable {
                    after = [ "slskd.service" ];
                    wants = [ "slskd.service" ];
                })
                (mkIf sy.proxy {
                    after = [ "arr-proxy-env.service" ];
                    requires = [ "arr-proxy-env.service" ];
                })
            ];

            virtualisation.oci-containers.containers.soulsync = {
                image = "boulderbadgedad/soulsync:latest";
                environment = {
                    PUID = "1000";
                    PGID = "100";
                    UMASK = "022";
                    FLASK_ENV = "production";
                    PYTHONPATH = "/app";
                    SOULSYNC_CONFIG_PATH = "/app/config/config.json";
                    TZ = if (config.time.timeZone == null || config.time.timeZone == "") then "UTC" else config.time.timeZone;
                };
                volumes = [
                    "${sy.dataDir}/config:/app/config"
                    "${sy.dataDir}/logs:/app/logs"
                    "${sy.dataDir}/data:/app/data"
                    "${sy.downloadsDir}:/app/downloads"
                    "${sy.stagingDir}:/app/Staging"
                    "${sy.transferDir}:/app/Transfer"
                ];
                extraOptions =
                    [
                        "--network=host"
                        "--pull=always"
                    ]
                    ++ optionals sy.proxy [ "--env-file=${arrProxyEnvFile}" ]
                    ++ sy.extraOptions;
            };

            homelab.traefik.routes = mkIf config.homelab.traefik.enable [
                {
                    name = "soulsync";
                    subdomain = sy.subdomain;
                    backendUrl = "http://127.0.0.1:${toString sy.port}";
                }
            ];

            homelab.glance.services = mkIf config.homelab.glance.enable [
                {
                    title = "SoulSync";
                    subdomain = sy.subdomain;
                    icon = "mdi:headphones-settings";
                    group = "*arr";
                    priority = 6;
                }
            ];
        })
    ];
}
