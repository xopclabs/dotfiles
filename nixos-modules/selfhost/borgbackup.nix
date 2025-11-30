{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.borgbackup;

    # Shared option definitions for defaults and jobs
    jobOptions = {
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

        sshKey = mkOption {
            type = types.str;
            default = "/home/${config.metadata.user}/.ssh/id_ed25519";
            description = "Path to SSH private key for remote repositories";
        };

        environmentFile = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Path to environment file containing BORG_PASSPHRASE";
        };
    };

    # Merge job config with defaults (job values take precedence)
    mergeWithDefaults = job: {
        paths = job.paths;
        repo = job.repo;
        schedule = if job.schedule != "daily" then job.schedule else cfg.defaults.schedule;
        compression = if job.compression != "zstd" then job.compression else cfg.defaults.compression;
        exclude = if job.exclude != [] then job.exclude else cfg.defaults.exclude;
        prune.keep = {
            within = if job.prune.keep.within != null then job.prune.keep.within else cfg.defaults.prune.keep.within;
            hourly = if job.prune.keep.hourly != null then job.prune.keep.hourly else cfg.defaults.prune.keep.hourly;
            daily = if job.prune.keep.daily != null then job.prune.keep.daily else cfg.defaults.prune.keep.daily;
            weekly = if job.prune.keep.weekly != null then job.prune.keep.weekly else cfg.defaults.prune.keep.weekly;
            monthly = if job.prune.keep.monthly != null then job.prune.keep.monthly else cfg.defaults.prune.keep.monthly;
            yearly = if job.prune.keep.yearly != null then job.prune.keep.yearly else cfg.defaults.prune.keep.yearly;
        };
        encryption = {
            mode = if job.encryption.mode != "none" then job.encryption.mode else cfg.defaults.encryption.mode;
            passCommand = "cat ${config.sops.secrets.backup-passphrase.path}";
        };
        sshKey = job.sshKey;
        environmentFile = if job.environmentFile != null then job.environmentFile else cfg.defaults.environmentFile;
    };
in
{
    options.homelab.borgbackup = {
        enable = mkEnableOption "BorgBackup automated backups";

        user = mkOption {
            type = types.str;
            default = "root";
            description = "User to run backup jobs as";
        };

        defaults = mkOption {
            type = types.submodule { options = jobOptions; };
            default = {};
            description = "Default values applied to all jobs (job-specific values take precedence)";
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
                } // jobOptions;
            });
            default = {};
            description = "Backup job configurations";
        };

        # SSH known hosts for remote repositories
        knownHosts = mkOption {
            type = types.attrsOf (types.submodule {
                options = {
                    publicKey = mkOption {
                        type = types.str;
                        description = "SSH public key for the host";
                    };
                };
            });
            default = {};
            description = "SSH known hosts for remote borg repositories";
        };
    };

    config = mkIf cfg.enable {
        services.borgbackup.jobs = mapAttrs (name: jobRaw: let
            job = mergeWithDefaults jobRaw;
        in {
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

            # Remote repository options
            environment = optionalAttrs (job.sshKey != null) {
                BORG_RSH = "ssh -o StrictHostKeyChecking=accept-new -i ${job.sshKey}";
            };
        }) cfg.jobs;

        # BorgBase passphrase secret
        sops.secrets."backup-passphrase" = {
            sopsFile = ../../secrets/shared/personal.yaml;
        };

        # SSH known hosts for remote borg repositories
        programs.ssh.knownHosts = mapAttrs (name: host: {
            publicKey = host.publicKey;
        }) cfg.knownHosts;

        # Ensure borg is available
        environment.systemPackages = [ pkgs.borgbackup ];
    };
}

