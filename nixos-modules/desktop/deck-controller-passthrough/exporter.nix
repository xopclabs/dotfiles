{ cfg, scripts, usbip, ... }:

{
    networking.firewall.allowedTCPPorts = [ 3240 ];

    systemd.services.deck-controller-passthrough-usbipd = {
        description = "USB/IP daemon for Steam Deck controller passthrough";
        serviceConfig = {
            ExecStart = "${usbip}/bin/usbipd";
            Restart = "on-failure";
        };
    };

    systemd.services.deck-controller-passthrough-exporter = {
        description = "Export the Steam Deck controller over USB/IP";
        requires = [ "deck-controller-passthrough-usbipd.service" ];
        after = [ "network-online.target" "deck-controller-passthrough-usbipd.service" ];
        wants = [ "network-online.target" ];
        unitConfig.PartOf = [ "deck-controller-passthrough-usbipd.service" ];
        serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = scripts.exporterStart;
            ExecStop = scripts.exporterStop;
        };
    };
}
