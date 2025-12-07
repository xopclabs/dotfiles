{ config, lib, ... }:

with lib;
{
    options.metadata = {
        user = mkOption {
            type = types.str;
            description = "Main user of the system";
        };
        hostName = mkOption {
            type = types.str;
            description = "Hostname of the system";
        };
        repositoryRelPath = mkOption {
            type = types.str;
            default = "dotfiles";
            description = "Repository path relative to home directory";
        };

        network = {
            ipv4 = mkOption {
                type = types.str;
                default = null;
                description = "Internal IP address of the system";
            };
            prefixLength = mkOption {
                type = types.int;
                default = 24;
                description = "Network prefix length (CIDR notation)";
            };
            defaultGateway = mkOption {
                type = types.str;
                default = null;
                description = "Default gateway of the system";
            };
        };

        selfhost = {
            mainIpv4 = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "IPv4 address the main server for selfhosting";
            };
            storage = {
                downloads = {
                    mainDir = mkOption {
                        type = types.str;
                        default = "/mnt/raid_pool/shared/downloads/torrent";
                        description = "Base directory general downloads";
                    };
                    moviesDir = mkOption {
                        type = types.str;
                        default = "/mnt/raid_pool/shared/downloads/torrent/movies";
                        description = "Base directory for movies downloads";
                    };
                    tvDir = mkOption {
                        type = types.str;
                        default = "/mnt/raid_pool/shared/downloads/torrent/tv-shows";
                        description = "Base directory for tv shows downloads";
                    };
                    musicDir = mkOption {
                        type = types.str;
                        default = "/mnt/raid_pool/shared/downloads/torrent/music";
                        description = "Base directory for music downloads";
                    };
                    incompleteDir = mkOption {
                        type = types.str;
                        default = null;
                        description = "Base directory for incomplete downloads";
                    };
                };
                media = {
                    moviesDir = mkOption {
                        type = types.str;
                        default = "/mnt/raid_pool/shared/media/movies";
                        description = "Base directory for movies media";
                    };
                    tvDir = mkOption {
                        type = types.str;
                        default = "/mnt/raid_pool/shared/media/tv";
                        description = "Base directory for tv shows media";
                    };
                    musicDir = mkOption {
                        type = types.str;
                        default = "/mnt/raid_pool/shared/media/music";
                        description = "Base directory for music media";
                    };
                };
                general = {
                    nextcloudDir = mkOption {
                        type = types.str;
                        default = "/mnt/raid_pool/nextcloud";
                        description = "Base directory for Nextcloud data";
                    };
                };
            };
        };

        hardware = {
            monitors = mkOption {
                type = types.attrsOf (types.submodule {
                    options = {
                        name = mkOption {
                            type = types.str;
                            description = "Monitor name as reported by wlr-randr or similar";
                        };
                        mode = mkOption {
                            type = types.str;
                            description = "Monitor resolution and refresh rate (e.g., '1920x1080@60')";
                        };
                        scale = mkOption {
                            type = types.float;
                            default = 1.0;
                            description = "Monitor scale factor";
                        };
                        transform = mkOption {
                            type = types.enum ["normal" "90" "180" "270" "flipped" "flipped-90" "flipped-180" "flipped-270"];
                            default = "normal";
                            description = "Monitor transformation (rotation/flipping)";
                        };
                        position = mkOption {
                            type = types.str;
                            description = "Monitor position (e.g., '0,0')";
                        };
                    };
                });
                default = null;
                description = "Hardware monitor configuration";
            };
        };
    };
}
