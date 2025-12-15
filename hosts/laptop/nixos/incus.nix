{ config, pkgs, ... }:

{
    # Enable nftables (required for Incus networking)
    networking.nftables.enable = true;
    networking.firewall.trustedInterfaces = [ "incusbr0" ];

    # Incus virtualization
    virtualisation.incus = {
        enable = true;
        ui.enable = true;  
        preseed = {
            networks = [
                {
                    config = {
                        "ipv4.address" = "10.10.150.1/24";
                        "ipv4.nat" = "true";
                    };
                    name = "incusbr0";
                    type = "bridge";
                }
            ];
            profiles = [
                {
                    devices = {
                        eth0 = {
                            name = "eth0";
                            network = "incusbr0";
                            type = "nic";
                        };
                        root = {
                            path = "/";
                            pool = "default";
                            size = "128GiB";
                            type = "disk";
                        };
                    };
                    name = "default";
                }
            ];
            storage_pools = [
                {
                    config.source = "/var/lib/incus/storage-pools/default";
                    driver = "dir";
                    name = "default";
                }
            ];
        };
    };

    users.users."${config.metadata.user}".extraGroups = [ "incus-admin" ];

    networking.firewall.allowedTCPPorts = [ 8443 ];

    # IOMMU and VFIO for PCI passthrough (Windows VM with GPU)
    boot = {
        kernelParams = [
            "intel_iommu=on"
            "iommu=pt"
        ];
        kernelModules = [
            "vfio"
            "vfio_iommu_type1"
            "vfio_pci"
        ];
    };
}

