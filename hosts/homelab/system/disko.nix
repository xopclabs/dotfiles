{
    disko.devices.disk.primary = {
        device = "/dev/sda";
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
                        subvolumes."/root" = {
                            mountOptions = [ "compress=zstd" ]; 
                            mountpoint = "/";
                        };

                        # Home subvolume
                        subvolumes."/home" = {
                            mountOptions = [ "compress=zstd" ];
                            mountpoint = "/home";
                        };

                        # Nix subvolume
                        subvolumes."/nix" = {
                            mountOptions = [
                                "compress=zstd"
                                "noatime"
                                "noacl"
                            ]; # Optimize for Nix store
                            mountpoint = "/nix";
                        };

                        # Swap subvolume
                        subvolumes."/swap" = {
                            mountpoint = "/.swap";
                            swap = {
                                swapfile.size = "8G";
                            };
                        };
                    };
                };
            };
        };
    };
}