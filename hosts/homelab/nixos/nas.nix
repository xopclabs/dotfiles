{ config, pkgs, lib, ... }:

{
    networking.hostId = "263d8065";

    boot = {
        supportedFilesystems = [ "zfs" ];
        zfs = {
            forceImportRoot = false;
            extraPools = [ "backup_pool" "raid_pool" ];
        };
    };

    services.zfs = {
        autoScrub = {
            enable = true;
            interval = "weekly";
        };
        trim = {
            enable = true;
            interval = "weekly";
        };
    };

    # NFS server for Proxmox backups
    services.nfs.server = {
        enable = true;
        lockdPort = 4001;
        mountdPort = 4002;
        statdPort = 4000;
        exports = ''
            /mnt/raid_pool/proxmox-backup  192.168.254.0/24(rw,sync,no_subtree_check,no_root_squash)
            /mnt/raid_pool/shared  192.168.254.0/24(rw,sync,no_subtree_check,no_root_squash)
        '';
    };
    # Open firewall for NFS
    networking.firewall = {
        allowedTCPPorts = [
            111  
            2049  
            4000  
            4001  
            4002  
        ];
        allowedUDPPorts = [
            111  
            2049  
            4000  
            4001  
            4002  
        ];
    };
}

