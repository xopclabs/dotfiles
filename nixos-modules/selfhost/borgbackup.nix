{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.borgbackup;
in
{
    options.homelab.borgbackup = {
        enable = mkEnableOption "BorgBackup automated backups";

        user = mkOption {
            type = types.str;
            default = "root";
            description = "User to run backup jobs as";
        };

        jobs = mkOption {
            type = types.attrsOf (types.submodule {
                options = {
                    paths = mkOption {
                        type = types.listOf types.str;
                        description = "Paths to backup";
                    };

                    repo = mkOption {
                        type = types.str;
                        description = "Path to the Borg repository";
                    };

                    schedule = mkOption {
                        type = types.str;
                        default = "daily";
                        description = ''
                            Systemd calendar expression for when to run backups.
                            Examples: "hourly", "daily", "weekly", "*-*-* 02:00:00"
                        '';
                    };

                    compression = mkOption {
                        type = types.str;
                        default = "zstd";
                        description = ''
                            Compression algorithm. Options: none, lz4, zstd, zlib, lzma.
                            Use "none" for already-compressed data.
                        '';
                    };

                    exclude = mkOption {
                        type = types.listOf types.str;
                        default = [];
                        description = "Patterns to exclude from backup";
                    };

                    prune = {
                        keep = {
                            within = mkOption {
                                type = types.nullOr types.str;
                                default = null;
                                description = "Keep all backups within this time (e.g., '1d' for 1 day)";
                            };

                            hourly = mkOption {
                                type = types.nullOr types.int;
                                default = null;
                                description = "Number of hourly backups to keep";
                            };

                            daily = mkOption {
                                type = types.nullOr types.int;
                                default = null;
                                description = "Number of daily backups to keep";
                            };

                            weekly = mkOption {
                                type = types.nullOr types.int;
                                default = null;
                                description = "Number of weekly backups to keep";
                            };

                            monthly = mkOption {
                                type = types.nullOr types.int;
                                default = null;
                                description = "Number of monthly backups to keep";
                            };

                            yearly = mkOption {
                                type = types.nullOr types.int;
                                default = null;
                                description = "Number of yearly backups to keep";
                            };
                        };
                    };

                    encryption = {
                        mode = mkOption {
                            type = types.enum [ "none" "repokey" "repokey-blake2" "keyfile" "keyfile-blake2" ];
                            default = "none";
                            description = "Encryption mode for the repository";
                        };

                        passCommand = mkOption {
                            type = types.nullOr types.str;
                            default = null;
                            description = "Command to get the encryption passphrase";
                        };
                    };
                };
            });
            default = {};
            description = "Backup job configurations";
        };
    };

    config = mkIf cfg.enable {
        services.borgbackup.jobs = mapAttrs (name: job: {
            paths = job.paths;
            repo = job.repo;
            
            # Encryption
            encryption = {
                mode = job.encryption.mode;
                passCommand = job.encryption.passCommand;
            };

            # Compression
            compression = job.compression;

            # Exclusions
            exclude = job.exclude;

            # Schedule
            startAt = job.schedule;

            # Pruning
            prune.keep = filterAttrs (n: v: v != null) {
                inherit (job.prune.keep) within hourly daily weekly monthly yearly;
            };

            # Repository initialization
            doInit = true;

            # Extra borg create args for better defaults
            extraCreateArgs = "--stats --checkpoint-interval 600";

            # Run as specified user
            user = cfg.user;

            # Persist borg cache for faster subsequent backups
            persistentTimer = true;
        }) cfg.jobs;

        # Ensure borg is available
        environment.systemPackages = [ pkgs.borgbackup ];
    };
}

