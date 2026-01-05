{ config, pkgs, lib, ... }:

{
    networking.hostId = "263d8065";

    boot = {
        supportedFilesystems = [ "zfs" ];
        zfs = {
            forceImportRoot = false;
            extraPools = [ "backup_pool" "raid_pool" ];
        };
        kernelParams = [
            # Limit ZFS ARC to 8GB max
            "zfs.zfs_arc_max=8589934592"
        ];
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

    # NFS - works for light workloads, but causes RCU stalls under heavy I/O
    # Using Samba for Proxmox backups instead.
    services.nfs.server = {
        enable = true;
        lockdPort = 4001;
        mountdPort = 4002;
        statdPort = 4000;
        exports = ''
            /mnt/raid_pool/shared  192.168.254.0/24(rw,async,no_subtree_check,no_root_squash) 10.250.250.0/24(rw,async,no_subtree_check,no_root_squash)
        '';
    };

    services.samba = {
        enable = true;
        openFirewall = true;
        settings = {
            global = {
                workgroup = "WORKGROUP";
                "server string" = "homelab";
                "netbios name" = "homelab";
                security = "user";
                "hosts allow" = "192.168.254. 10.250.250. 127.0.0.1 localhost";
                "hosts deny" = "0.0.0.0/0";
                "guest account" = "nobody";
                "map to guest" = "bad user";
            };
            shared = {
                path = "/mnt/raid_pool/shared";
                browseable = "yes";
                "read only" = "no";
                "guest ok" = "no";
                "valid users" = "@users";
                "create mask" = "0664";
                "directory mask" = "0775";
            };
            "proxmox-backup" = {
                path = "/mnt/raid_pool/proxmox-backup";
                browseable = "yes";
                "read only" = "no";
                "guest ok" = "no";
                "valid users" = "@users";
                "create mask" = "0644";
                "directory mask" = "0755";
                "force user" = "root";
                "force group" = "root";
                "strict locking" = "no";
            };
        };
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