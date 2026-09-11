{ scripts, ... }:

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
