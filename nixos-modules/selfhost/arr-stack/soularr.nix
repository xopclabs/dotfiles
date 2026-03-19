{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.arr-stack.soularr;
    arrCfg = config.homelab.arr-stack;

    boolToIni = b: if b then "True" else "False";

    configTemplate = pkgs.writeText "soularr-config.ini" ''
        [Lidarr]
        api_key = __LIDARR_API_KEY__
        host_url = __LIDARR_HOST_URL__
        download_dir = ${cfg.slskd.downloadsDir}
        disable_sync = ${boolToIni cfg.lidarr.disableSync}

        [Slskd]
        api_key = __SLSKD_API_KEY__
        host_url = http://127.0.0.1:${toString cfg.slskd.port}
        url_base = /
        download_dir = /downloads
        delete_searches = ${boolToIni cfg.slskd.deleteSearches}
        stalled_timeout = ${toString cfg.slskd.stalledTimeout}

        [Release Settings]
        use_most_common_tracknum = ${boolToIni cfg.releaseSettings.useMostCommonTracknum}
        allow_multi_disc = ${boolToIni cfg.releaseSettings.allowMultiDisc}
        accepted_countries = ${concatStringsSep "," cfg.releaseSettings.acceptedCountries}
        accepted_formats = ${concatStringsSep "," cfg.releaseSettings.acceptedFormats}

        [Search Settings]
        search_timeout = ${toString cfg.searchSettings.searchTimeout}
        maximum_peer_queue = ${toString cfg.searchSettings.maximumPeerQueue}
        minimum_peer_upload_speed = ${toString cfg.searchSettings.minimumPeerUploadSpeed}
        minimum_filename_match_ratio = ${toString cfg.searchSettings.minimumFilenameMatchRatio}
        allowed_filetypes = ${concatStringsSep "," cfg.searchSettings.allowedFiletypes}
        ignored_users = ${concatStringsSep "," cfg.searchSettings.ignoredUsers}
        search_for_tracks = ${boolToIni cfg.searchSettings.searchForTracks}
        album_prepend_artist = ${boolToIni cfg.searchSettings.albumPrependArtist}
        track_prepend_artist = ${boolToIni cfg.searchSettings.trackPrependArtist}
        search_type = ${cfg.searchSettings.searchType}
        number_of_albums_to_grab = ${toString cfg.searchSettings.numberOfAlbumsToGrab}
        remove_wanted_on_failure = ${boolToIni cfg.searchSettings.removeWantedOnFailure}
        title_blacklist = ${concatStringsSep "," cfg.searchSettings.titleBlacklist}
        search_source = ${cfg.searchSettings.searchSource}

        [Logging]
        level = ${cfg.logging.level}
        format = ${cfg.logging.format}
        datefmt = ${cfg.logging.datefmt}
    '';
in
{
    options.homelab.arr-stack.soularr = {
        enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable Soularr (Lidarr + Soulseek integration via Slskd)";
        };

        slskd = {
            subdomain = mkOption {
                type = types.str;
                description = "Subdomain for Slskd web interface";
            };

            port = mkOption {
                type = types.int;
                default = 5530;
                description = "Port for Slskd web interface";
            };

            openFirewall = mkEnableOption "Open firewall for Soulseek listen port";

            downloadsDir = mkOption {
                type = types.path;
                default = "/var/lib/slskd/downloads";
                description = "Directory for Slskd downloads (must be accessible by Lidarr)";
            };

            shareDirectories = mkOption {
                type = types.listOf types.str;
                default = [ config.metadata.selfhost.storage.media.musicDir ];
                description = "Directories to share on Soulseek network";
            };

            deleteSearches = mkOption {
                type = types.bool;
                default = false;
                description = "Delete Slskd search results after Soularr runs";
            };

            stalledTimeout = mkOption {
                type = types.int;
                default = 3600;
                description = "Max seconds to wait for stalled downloads before giving up";
            };
        };

        lidarr = {
            disableSync = mkOption {
                type = types.bool;
                default = false;
                description = "If true, Lidarr won't auto-import downloaded files from Slskd";
            };
        };

        releaseSettings = {
            useMostCommonTracknum = mkOption {
                type = types.bool;
                default = true;
                description = "Pick release with most common track count";
            };

            allowMultiDisc = mkOption {
                type = types.bool;
                default = true;
                description = "Allow multi-disc releases";
            };

            acceptedCountries = mkOption {
                type = types.listOf types.str;
                default = [ "Europe" "Japan" "United Kingdom" "United States" "[Worldwide]" "Australia" "Canada" ];
                description = "Accepted Musicbrainz release countries";
            };

            acceptedFormats = mkOption {
                type = types.listOf types.str;
                default = [ "CD" "Digital Media" "Vinyl" ];
                description = "Accepted Musicbrainz release formats";
            };
        };

        searchSettings = {
            searchTimeout = mkOption {
                type = types.int;
                default = 5000;
                description = "Search timeout in milliseconds";
            };

            maximumPeerQueue = mkOption {
                type = types.int;
                default = 50;
                description = "Maximum peer queue length";
            };

            minimumPeerUploadSpeed = mkOption {
                type = types.int;
                default = 0;
                description = "Minimum peer upload speed in bits/sec (0 = no limit)";
            };

            minimumFilenameMatchRatio = mkOption {
                type = types.float;
                default = 0.8;
                description = "Minimum match ratio between Lidarr track and Soulseek filename";
            };

            allowedFiletypes = mkOption {
                type = types.listOf types.str;
                default = [ "flac 16/44.1" "flac 24/48" "flac 24/192" "flac 24/96" "flac" "mp3 320" ];
                description = "Preferred file types and qualities (most to least preferred)";
            };

            ignoredUsers = mkOption {
                type = types.listOf types.str;
                default = [];
                description = "Soulseek users to ignore";
            };

            searchForTracks = mkOption {
                type = types.bool;
                default = true;
                description = "Search for individual track titles (still matches full albums)";
            };

            albumPrependArtist = mkOption {
                type = types.bool;
                default = true;
                description = "Prepend artist name when searching for albums";
            };

            trackPrependArtist = mkOption {
                type = types.bool;
                default = true;
                description = "Prepend artist name when searching for tracks";
            };

            searchType = mkOption {
                type = types.enum [ "all" "incrementing_page" "first_page" ];
                default = "incrementing_page";
                description = "Search mode: all, incrementing_page, or first_page";
            };

            numberOfAlbumsToGrab = mkOption {
                type = types.int;
                default = 10;
                description = "Albums to process per run";
            };

            removeWantedOnFailure = mkOption {
                type = types.bool;
                default = false;
                description = "Unmonitor album on failure (logs to failure_list.txt)";
            };

            titleBlacklist = mkOption {
                type = types.listOf types.str;
                default = [];
                description = "Blacklisted words in album or track titles (case-insensitive)";
            };

            searchSource = mkOption {
                type = types.enum [ "missing" "cutoff_unmet" ];
                default = "missing";
                description = "Lidarr search source";
            };
        };

        logging = {
            level = mkOption {
                type = types.enum [ "DEBUG" "INFO" "WARNING" "ERROR" "CRITICAL" ];
                default = "INFO";
                description = "Python logging level";
            };

            format = mkOption {
                type = types.str;
                default = "[%(levelname)s|%(module)s|L%(lineno)d] %(asctime)s: %(message)s";
                description = "Python logging format string";
            };

            datefmt = mkOption {
                type = types.str;
                default = "%Y-%m-%dT%H:%M:%S%z";
                description = "Python logging date format";
            };
        };

        scriptInterval = mkOption {
            type = types.int;
            default = 300;
            description = "How often Soularr runs in seconds";
        };

        dataDir = mkOption {
            type = types.path;
            default = "/var/lib/soularr";
            description = "Directory for Soularr runtime data";
        };
    };

    config = mkIf (arrCfg.enable && cfg.enable) {
        sops.secrets."soularr/slskd-env" = {
            sopsFile = ../../../secrets/shared/selfhost.yaml;
        };
        sops.secrets."soularr/lidarr-api-key" = {
            sopsFile = ../../../secrets/shared/selfhost.yaml;
        };

        services.slskd = {
            enable = true;
            domain = null;
            environmentFile = "/run/slskd-env";
            openFirewall = cfg.slskd.openFirewall;
            group = "users";
            settings = {
                directories.downloads = cfg.slskd.downloadsDir;
                shares.directories = cfg.slskd.shareDirectories;
                web.port = cfg.slskd.port;
            };
        };

        systemd.services.slskd = {
            after = [ "soularr-config.service" ];
            requires = [ "soularr-config.service" ];
            serviceConfig.UMask = "0002";
        };

        systemd.tmpfiles.rules = [
            "d ${cfg.dataDir} 0750 ${config.metadata.user} users -"
            "d ${cfg.slskd.downloadsDir} 2775 slskd users -"
            "a+ ${cfg.slskd.downloadsDir} - - - - d:g:users:rwx,g:users:rwx"
        ];

        systemd.services.soularr-config = {
            description = "Generate Soularr config and Slskd environment";
            wantedBy = [ "multi-user.target" ];
            before = [ "docker-soularr.service" "slskd.service" ];
            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
            };
            script = ''
                set -a
                source ${config.sops.secrets."traefik/env".path}
                set +a

                KEY_FILE="${cfg.dataDir}/slskd-api-key"
                if [ ! -f "$KEY_FILE" ]; then
                    ${pkgs.openssl}/bin/openssl rand -hex 16 > "$KEY_FILE"
                    chmod 600 "$KEY_FILE"
                fi
                SLSKD_KEY=$(cat "$KEY_FILE")

                cat ${config.sops.secrets."soularr/slskd-env".path} > /run/slskd-env
                echo "SLSKD_API_KEY=$SLSKD_KEY" >> /run/slskd-env
                chmod 600 /run/slskd-env

                LIDARR_KEY=$(cat ${config.sops.secrets."soularr/lidarr-api-key".path})
                LIDARR_URL="https://${arrCfg.lidarr.subdomain}.$DOMAIN"

                ${pkgs.gnused}/bin/sed \
                    -e "s|__LIDARR_API_KEY__|$LIDARR_KEY|" \
                    -e "s|__SLSKD_API_KEY__|$SLSKD_KEY|" \
                    -e "s|__LIDARR_HOST_URL__|$LIDARR_URL|" \
                    ${configTemplate} > ${cfg.dataDir}/config.ini
                chmod 640 ${cfg.dataDir}/config.ini
            '';
        };

        virtualisation.oci-containers.containers.soularr = {
            image = "mrusse08/soularr:latest";
            volumes = [
                "${cfg.slskd.downloadsDir}:/downloads"
                "${cfg.dataDir}:/data"
            ];
            environment = {
                TZ = "UTC";
                SCRIPT_INTERVAL = toString cfg.scriptInterval;
            };
            extraOptions = [
                "--network=host"
                "--pull=always"
            ];
        };

        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "slskd";
                subdomain = cfg.slskd.subdomain;
                backendUrl = "http://127.0.0.1:${toString cfg.slskd.port}";
            }
        ];

        homelab.glance.services = mkIf config.homelab.glance.enable [
            {
                title = "Soulseek";
                subdomain = cfg.slskd.subdomain;
                icon = "mdi:bird";
                group = "*arr";
                priority = 5;
            }
        ];
    };
}
