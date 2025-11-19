{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.postgres;
in
{
    options.homelab.postgres = {
        enable = mkEnableOption "PostgreSQL database service";
        
        port = mkOption {
            type = types.int;
            default = 5432;
            description = "PostgreSQL port";
        };
        
        dataDir = mkOption {
            type = types.str;
            default = "/var/lib/postgresql/${config.services.postgresql.package.psqlSchema}";
            description = "PostgreSQL data directory";
        };
        
        databases = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "List of databases to ensure exist";
        };
        
        ensureUsers = mkOption {
            type = types.listOf (types.submodule {
                options = {
                    name = mkOption {
                        type = types.str;
                        description = "Username";
                    };
                    ensureDBOwnership = mkOption {
                        type = types.bool;
                        default = true;
                        description = "Ensure user owns database with matching name";
                    };
                };
            });
            default = [];
            description = "List of users to ensure exist";
        };
        
        enableTCPIP = mkOption {
            type = types.bool;
            default = false;
            description = "Enable TCP/IP connections (in addition to Unix socket)";
        };
        
        authentication = mkOption {
            type = types.lines;
            default = ''
                local all all peer
                host all all 127.0.0.1/32 trust
                host all all ::1/128 trust
            '';
            description = "PostgreSQL authentication configuration (pg_hba.conf)";
        };
        
        package = mkOption {
            type = types.package;
            default = pkgs.postgresql_16;
            defaultText = literalExpression "pkgs.postgresql_16";
            description = "PostgreSQL package to use";
        };
        
        settings = mkOption {
            type = types.attrsOf types.anything;
            default = {};
            description = "Additional PostgreSQL settings";
        };
    };
    
    config = mkIf cfg.enable {
        services.postgresql = {
            enable = true;
            package = cfg.package;
            dataDir = cfg.dataDir;
            enableTCPIP = cfg.enableTCPIP;
            authentication = cfg.authentication;
            
            ensureDatabases = cfg.databases;
            ensureUsers = map (user: {
                name = user.name;
                ensureDBOwnership = user.ensureDBOwnership;
            }) cfg.ensureUsers;
            
            settings = mkMerge [
                {
                    port = cfg.port;
                }
                {
                    # Sensible defaults
                    max_connections = mkDefault 100;
                    shared_buffers = mkDefault "128MB";
                    effective_cache_size = mkDefault "512MB";
                    maintenance_work_mem = mkDefault "64MB";
                    checkpoint_completion_target = mkDefault 0.9;
                    wal_buffers = mkDefault "4MB";
                    default_statistics_target = mkDefault 100;
                    random_page_cost = mkDefault 1.1;
                    effective_io_concurrency = mkDefault 200;
                    work_mem = mkDefault "4MB";
                    min_wal_size = mkDefault "1GB";
                    max_wal_size = mkDefault "4GB";
                    max_worker_processes = mkDefault 4;
                    max_parallel_workers_per_gather = mkDefault 2;
                    max_parallel_workers = mkDefault 4;
                    max_parallel_maintenance_workers = mkDefault 2;
                }
                cfg.settings
            ];
        };
        
        # Backup script
        systemd.services.postgresql-backup = {
            description = "PostgreSQL backup";
            after = [ "postgresql.service" ];
            requires = [ "postgresql.service" ];
            
            serviceConfig = {
                Type = "oneshot";
                User = "postgres";
                ExecStart = pkgs.writeShellScript "postgresql-backup" ''
                    set -euo pipefail
                    BACKUP_DIR="/var/backup/postgresql"
                    mkdir -p "$BACKUP_DIR"
                    DATE=$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)
                    
                    # Backup all databases
                    ${cfg.package}/bin/pg_dumpall -c > "$BACKUP_DIR/backup-$DATE.sql"
                    
                    # Keep only last 7 backups
                    ${pkgs.coreutils}/bin/ls -t "$BACKUP_DIR"/backup-*.sql | ${pkgs.coreutils}/bin/tail -n +8 | ${pkgs.findutils}/bin/xargs -r ${pkgs.coreutils}/bin/rm
                '';
            };
        };
        
        systemd.timers.postgresql-backup = {
            description = "PostgreSQL backup timer";
            wantedBy = [ "timers.target" ];
            
            timerConfig = {
                OnCalendar = "daily";
                Persistent = true;
            };
        };
        
        # Ensure backup directory exists
        systemd.tmpfiles.rules = [
            "d /var/backup/postgresql 0750 postgres postgres -"
        ];
    };
}

