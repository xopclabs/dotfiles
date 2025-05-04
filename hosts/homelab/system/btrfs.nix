{ config, pkgs, inputs, ... }:

{
    services.btrfs = {
        autoScrub = {
            enable = true;
            interval = "weekly";
            fileSystem = [ "/" ];
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
                BACKGROUND_COMPARISON = "yes";
                NUMBER_CLEANUP = "no";
                NUMBER_MIN_AGE = "1800";
                NUMBER_LIMIT = "50";
                NUMBER_LIMIT_IMPORTANT = "10";
                EMPTY_PRE_POST_CLEANUP = "yes";
                EMPTY_PRE_POST_MIN_AGE = "1800";
            };
        in {
            root = {
                SUBVOLUME = "/";
                inherit params;
            };
            home = {
                SUBVOLUME = "/home";
                inherit params;
            };
        };
    };
}