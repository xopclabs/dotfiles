{ config, pkgs, inputs, ... }:

{
    services.btrfs = {
        autoScrub = {
            enable = true;
            interval = "weekly";
            fileSystems = [ "/" ];
        };
    };

    # Snaphots
    services.snapper = {
        snapshotInterval = "hourly";
        cleanupInterval = "1w";
        configs = let
            params = {
                TIMELINE_CREATE = true;
                TIMELINE_CLEANUP = true;
                TIMELINE_LIMIT_HOURLY = "10";
                TIMELINE_LIMIT_DAILY = "7";
                TIMELINE_LIMIT_WEEKLY = "0";
                TIMELINE_LIMIT_MONTHLY = "0";
                TIMELINE_LIMIT_YEARLY = "0";
            };
        in {
            root = {
                SUBVOLUME = "/var";
            } // params;
            home = {
                SUBVOLUME = "/home";
            } // params;
        };
    };
}
