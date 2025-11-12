{ ... }:

{
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
                    moviesDir = "/mnt/nas/downloads/torrent/movies";
                    tvDir = "/mnt/nas/downloads/torrent/tv";
                    musicDir = "/mnt/nas/downloads/torrent/music";
                    otherDir = "/mnt/nas/downloads/torrent/other";
                    incompleteDir = "/mnt/nas/downloads/torrent/.incomplete";
                };
                media = {
                    moviesDir = "/mnt/nas/media/movies";
                    tvDir = "/mnt/nas/media/tv";
                    musicDir = "/mnt/nas/media/music";
                };
                services = "/mnt/nas-containers";
            };
        };

    };
}

