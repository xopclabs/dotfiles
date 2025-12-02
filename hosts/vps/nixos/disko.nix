let
    defaultMountOptions = [ "compress=zstd:1" ];
in {
    disko.devices.disk.primary = {
        device = "/dev/vda";
        type = "disk";
        content = {
            type = "gpt";
            partitions = {

                # BIOS boot partition (required for GPT + BIOS)
                boot = {
                    size = "1M";
                    type = "EF02";
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
                                swapfile.size = "512M";
                            };
                        };
                    };
                };
            };
        };
    };
}