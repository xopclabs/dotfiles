let
    defaultMountOptions = [ "compress=zstd:1" ];
in {
    disko.devices.disk.primary = {
        device = "/dev/nvme0n1";
        type = "disk";
        content = {
            type = "gpt";
            partitions = {

                # EFI Partition
                ESP = {
                    size = "512M";
                    type = "EF00";
                    content = {
                        type = "filesystem";
                        format = "vfat";
                        mountpoint = "/boot";
                        mountOptions = [
                            "defaults"
                            "umask=0077"
                        ];
                    };
                };

                # Btrfs Root Partition
                root = {
                    size = "100%"; # Use remaining space
                    type = "8300"; # Linux filesystem type
                    content = {
                        type = "btrfs";

                        # Root subvolume
                        subvolumes."@" = {
                            mountOptions = defaultMountOptions; 
                            mountpoint = "/";
                        };
                        
                        # State subvolume
                        subvolumes."@var" = {
                            mountOptions = defaultMountOptions;
                            mountpoint = "/var";
                        };
                        subvolumes."@var-snapshots" = {
                            mountOptions = defaultMountOptions;
                            mountpoint = "/var/.snapshots";
                        };

                        # Home subvolume
                        subvolumes."@home" = {
                            mountOptions = defaultMountOptions;
                            mountpoint = "/home";
                        };
                        subvolumes."@home-snapshots" = {
                            mountOptions = defaultMountOptions;
                            mountpoint = "/home/.snapshots";
                        };

                        # Nix subvolume
                        subvolumes."@nix" = {
                            mountOptions = defaultMountOptions ++ [ "noatime" "noacl" ]; 
                            mountpoint = "/nix";
                        };

                        # Swap subvolume
                        subvolumes."@swap" = {
                            mountpoint = "/.swap";
                            swap = {
                                swapfile.size = "16G";
                            };
                        };
                    };
                };
            };
        };
    };
}
