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
                    mainDir = "/mnt/nas/downloads/torrent";
                    moviesDir = "/mnt/nas/downloads/torrent/movies";
                    tvDir = "/mnt/nas/downloads/torrent/tv";
                    musicDir = "/mnt/nas/downloads/torrent/music";
                };
                media = {
                    moviesDir = "/mnt/nas/media/movies";
                    tvDir = "/mnt/nas/media/tv";
                    musicDir = "/mnt/nas/media/music";
                };
            };
        };

    };
}

