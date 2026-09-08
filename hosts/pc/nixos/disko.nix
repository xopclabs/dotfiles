let
    defaultMountOptions = [ "compress=zstd:1" ];
in {
    disko.devices.disk.primary = {
        device = "/dev/nvme0n1";
        type = "disk";
        content = {
            type = "gpt";
            partitions = {
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

                root = {
                    size = "100%";
                    type = "8300";
                    content = {
                        type = "luks";
                        name = "cryptroot";
                        settings = {
                            allowDiscards = true;
                        };
                        content = {
                            type = "btrfs";
                            subvolumes = {
                                "@" = {
                                    mountOptions = defaultMountOptions;
                                    mountpoint = "/";
                                };
                                "@var" = {
                                    mountOptions = defaultMountOptions;
                                    mountpoint = "/var";
                                };
                                "@var-snapshots" = {
                                    mountOptions = defaultMountOptions;
                                    mountpoint = "/var/.snapshots";
                                };
                                "@home" = {
                                    mountOptions = defaultMountOptions;
                                    mountpoint = "/home";
                                };
                                "@home-snapshots" = {
                                    mountOptions = defaultMountOptions;
                                    mountpoint = "/home/.snapshots";
                                };
                                "@home-games" = {
                                    mountOptions = defaultMountOptions;
                                    mountpoint = "/home/xopc/games";
                                };
                                "@home-steam" = {
                                    mountOptions = defaultMountOptions;
                                    mountpoint = "/home/xopc/.local/share/Steam";
                                };
                                "@nix" = {
                                    mountOptions = defaultMountOptions ++ [ "noatime" "noacl" ];
                                    mountpoint = "/nix";
                                };
                                "@swap" = {
                                    mountpoint = "/.swap";
                                    swap.swapfile.size = "32G";
                                };
                            };
                        };
                    };
                };
            };
        };
    };
}
