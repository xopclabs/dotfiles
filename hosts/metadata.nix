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
                    picturesDir = mkOption {
                        type = types.str;
                        default = "/mnt/raid_pool/shared/media/pictures";
                        description = "Base directory for pictures/photos media";
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

        hardware = let
            monitorSubmodule = types.submodule {
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
                        type = types.nullOr types.str;
                        default = null;
                        description = "Legacy/manual monitor position (e.g., '0x0'). Prefer placement for dynamic layouts.";
                    };
                    internal = mkOption {
                        type = types.bool;
                        default = false;
                        description = "Whether this is a built-in/internal display.";
                    };
                    primary = mkOption {
                        type = types.bool;
                        default = false;
                        description = "Prefer this monitor as primary when connected.";
                    };
                    placement = {
                        relativeTo = mkOption {
                            type = types.enum [ "primary" ];
                            default = "primary";
                            description = "Anchor monitor for dynamic placement.";
                        };
                        side = mkOption {
                            type = types.enum [ "left" "right" "above" "below" "same" ];
                            default = "right";
                            description = "Side of the anchor where this monitor should be placed.";
                        };
                        align = mkOption {
                            type = types.enum [ "center" "start" "end" ];
                            default = "center";
                            description = "Alignment on the axis perpendicular to side.";
                        };
                        offsetFraction = mkOption {
                            type = types.listOf (types.oneOf [ types.float types.int ]);
                            default = [ 0.0 0.0 ];
                            description = "Additional x/y offset as fractions of the anchor logical size.";
                        };
                        stack = mkOption {
                            type = types.enum [ "horizontal" "vertical" "none" ];
                            default = "horizontal";
                            description = "How to stack monitors that share the same anchor side.";
                        };
                        order = mkOption {
                            type = types.int;
                            default = 50;
                            description = "Ordering inside a placement stack; lower values are closer to the anchor.";
                        };
                    };
                    connectors = mkOption {
                        type = types.listOf types.str;
                        default = [];
                        description = "DRM connector names this monitor may appear on, with the primary/preferred connector first.";
                    };
                    touch = mkOption {
                        type = types.listOf types.str;
                        default = [];
                        description = "Touch/tablet device names built into this panel (from hyprctl devices).";
                    };
                    variableRefreshRate = mkOption {
                        type = types.oneOf [ types.bool (types.enum [ "on-demand" ]) ];
                        default = false;
                        description = "Niri variable-refresh-rate setting: false, true, or \"on-demand\".";
                    };
                };
            };
        in {
            monitors = mkOption {
                type = types.attrsOf monitorSubmodule;
                default = {};
                description = "Monitor configurations keyed by stable host-local identifiers.";
            };
        };
    };
}
