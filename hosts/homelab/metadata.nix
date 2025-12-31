{ ... }:

{
    imports = [
        ../metadata.nix
    ];

    metadata = {
        user = "homelab";
        hostName = "homelab";
        network = {
            ipv4 = "192.168.254.10";
            defaultGateway = "192.168.254.1";
        };

        selfhost = {
            storage = {
                downloads = {
                    mainDir = "/mnt/raid_pool/shared/downloads/torrent";
                    moviesDir = "/mnt/raid_pool/shared/downloads/torrent/movies";
                    tvDir = "/mnt/raid_pool/shared/downloads/torrent/tv";
                    musicDir = "/mnt/raid_pool/shared/downloads/torrent/music";
                };
                media = {
                    moviesDir = "/mnt/raid_pool/shared/media/movies";
                    tvDir = "/mnt/raid_pool/shared/media/tv";
                    musicDir = "/mnt/raid_pool/shared/media/music";
                    picturesDir = "/mnt/raid_pool/immich";
                };
                general = {
                    nextcloudDir = "/mnt/raid_pool/nextcloud";
                };
            };
        };

    };
}

