{ config, lib, inputs, ... }:

{
    imports = [ 
        ../../../nixos-modules/selfhost/default.nix
    ];
    
    config.homelab = {
        # Essentials
        ddns = {
            enable = true;
            providers = {
                noip = {
                    updateInterval = "15min";
                    bootDelay = "5min";
                };
                afraid = {
                    updateInterval = "15min";
                    bootDelay = "5min";
                };
                duckdns = {
                    updateInterval = "15min";
                    bootDelay = "5min";
                };
            };
        };
        traefik = {
            enable = true;
            dashboardSubdomain = "traefik.vm.local";
            certificateDomains = [
                {
                    # VM services
                    main = "*.vm.local.$DOMAIN";
                    sans = [ "vm.local.$DOMAIN" ];
                }
                {
                    # Orange-Pi services 
                    main = "*.pi.local.$DOMAIN";
                    sans = [ "pi.local.$DOMAIN" ];
                }
                {
                    # Top-level local services
                    main = "*.local.$DOMAIN";
                    sans = [ "local.$DOMAIN" ];
                }
            ];
            routes = [
                {
                    name = "proxmox";
                    subdomain = "proxmox.local";
                    backendUrl = "https://192.168.254.20:8006";
                    insecureSkipVerify = true;
                }
                {
                    name = "scrutiny";
                    subdomain = "smart.local";
                    backendUrl = "http://192.168.254.21:8080";
                }
            ];
        };
        pihole_unbound = {
            enable = true;
            pihole.subdomain = "pihole.vm.local";
            unbound.forwardUpstream = true;
        };

        # VPN
        wireguard = {
            enable = true;
            listenPort = 51820;
            serverIP = "10.250.250.1/24";
            subnet = "10.250.250.0/24";
            externalInterface = "ens18";
            peers = {
                vps = {
                    publicKey = "HK4EezS2UTm64clhYLBa4QHAN/0ad/eyfv14N2ffnyA=";
                    allowedIPs = [ "10.250.250.2/32" ];
                };
                pavel = {
                    publicKey = "h/zTkj0tEVTYjJYZ3mvNLBblkKD9XMq7UpR03dlWSxo=";
                    allowedIPs = [ "10.250.250.3/32" ];
                };
                pavel-pc = {
                    publicKey = "dgkPzUZ+R3ODZWzY46DROU7VOOvuvndJucQlWEu0UV0=";
                    allowedIPs = [ "10.250.250.4/32" ];
                };
                tv = {
                    publicKey = "HrTCQLCg8TBAm/9+VfiOijQ17jRO18DrSyj+a/cpgDw=";
                    allowedIPs = [ "10.250.250.5/32" ];
                };
            };
            socks5Proxy = {
                enable = true;
                host = "127.0.0.1";
                port = 10808;
                redsocksPort = 12345;
            };
        };

        # Dashboard
        glance = {
            enable = true;
            subdomain = "vm.local";
            services = [
                {
                    title = "Proxmox";
                    subdomain = "proxmox.local";
                    icon = "si:proxmox";
                    group = "Other";
                }
                {
                    title = "Scrutiny";
                    subdomain = "smart.local";
                    icon = "mdi:harddisk";
                    group = "Other";
                }
            ];
            clock.count = 4;
            markets.count = 4;
        };


        # Torrents
        transmission = {
            enable = true;
            subdomain = "torrent.vm.local";
        };

        # Media automation
        arr-stack = {
            enable = true;

            radarr.subdomain = "movies.vm.local";
            sonarr.subdomain = "tv.vm.local";

            jellyfin.subdomain = "jellyfin.vm.local";
            jellyseerr = {
                subdomain = "request.vm.local";
                # Disable proxy - Quad9 DNS bypasses country restrictions, proxy breaks local service connections
                proxy = false;
            };

            bazarr.subdomain = "subtitles.vm.local";

            cleanuparr.subdomain = "cleanuparr.vm.local";
            huntarr.subdomain = "huntarr.vm.local";

            prowlarr.subdomain = "prowlarr.vm.local";
            flaresolverr.subdomain = "flaresolverr.vm.local";
        };

        # Geolocation
        traccar = {
            enable = true;
            subdomain = "traccar.vm.local";
        };

        # Cloud storage
        nextcloud = {
            enable = true;
            subdomain = "cloud.vm.local";
        };

        # Gaming servers
        minecraft = {
            enable = true;
            distantHorizons.enable = true;
            beta.enable = false;
        };

        # Drive health monitoring
        scrutiny = {
            # Disabled for now, not working due to running in a VM
            enable = false;
            subdomain = "drives.vm.local";
            devices = [ "/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde" ];
            # Daily at midnight
            collectorInterval = "0 0 * * *";
        };

        # Borg backups
        borgbackup = {
            enable = true;
            user = "root";

            defaults = {
                compression = "zstd";
                exclude = [
                    "/var/lib/docker/overlay2"
                    "/var/lib/containers/storage/overlay"
                    "*.tmp"
                    "*.cache"
                    "**/cache/**"
                    "**/Cache/**"
                ];
            };

            jobs = {
                services-state = {
                    paths = [ "/var/lib" ];
                    repo = "/mnt/backup_pool/backups/services-state";
                    schedule = "hourly";
                    prune.keep = { hourly = 12; daily = 7; };
                };
                services-state-borgbase = {
                    paths = [ "/var/lib" ];
                    repo = "whm3082m@whm3082m.repo.borgbase.com:repo";
                    schedule = "daily";
                    encryption.mode = "repokey-blake2";
                    prune.keep.daily = 2;
                };
                proxmox-backup = {
                    paths = [ "/mnt/raid_pool/proxmox-backup" ];
                    repo = "/mnt/backup_pool/backups/proxmox-backup";
                    schedule = "weekly";
                    compression = "none";
                    exclude = [];
                    prune.keep.weekly = 1;
                };
            };
        };
    };
}
