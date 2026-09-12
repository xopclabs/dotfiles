{ cfg, scripts, lib, ... }:

lib.mkMerge [
    {
        systemd.services.deck-controller-passthrough-importer = {
            description = "Import the Steam Deck controller over USB/IP";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = scripts.importerStart;
                ExecStop = scripts.importerStop;
            };
        };
    }
    (lib.mkIf cfg.gamescopeLifecycle {
        systemd.services.deck-controller-passthrough-gamescope = {
            description = "Enable Steam Deck controller forwarding for Gamescope";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = scripts.gamescopeStart;
                ExecStop = scripts.gamescopeStop;
            };
        };
    })
]
