{ cfg, scripts, usbip, lib, ... }:

lib.mkMerge [
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
            wantedBy = if cfg.bootActivation then [ "multi-user.target" ] else [];
            unitConfig.PartOf = [ "deck-controller-passthrough-usbipd.service" ];
            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = scripts.exporterStart;
                ExecStop = scripts.exporterStop;
            };
        };

        systemd.services.deck-controller-passthrough-watchdog = {
            description = "Restore Steam Deck local controls after USB/IP peer loss";
            after = [ "deck-controller-passthrough-exporter.service" ];
            wantedBy = [ "deck-controller-passthrough-exporter.service" ];
            partOf = [ "deck-controller-passthrough-exporter.service" ];
            serviceConfig = {
                Type = "simple";
                ExecStart = scripts.watchdog;
                Restart = "on-failure";
                RestartSec = 5;
                NoNewPrivileges = true;
                PrivateTmp = true;
                ProtectHome = true;
                ProtectSystem = "strict";
            };
        };
    }
    (lib.mkIf cfg.remoteControl.enable {
        networking.firewall.allowedTCPPorts = [ 22 ];

        services.openssh = {
            enable = true;
            settings = {
                PasswordAuthentication = false;
                PermitRootLogin = "no";
            };
        };

        users.users.${cfg.remoteControl.user} = {
            isSystemUser = true;
            group = cfg.remoteControl.user;
            shell = "/run/current-system/sw/bin/bash";
            openssh.authorizedKeys.keys = [
                "from=\"${cfg.allowedPeerAddress}\",command=\"${scripts.remoteCommand}\",no-agent-forwarding,no-port-forwarding,no-pty,no-user-rc,no-X11-forwarding ${cfg.remoteControl.authorizedKey}"
            ];
        };
        users.groups.${cfg.remoteControl.user} = {};

        security.sudo.extraRules = [
            {
                users = [ cfg.remoteControl.user ];
                commands = [{
                    command = toString scripts.remoteControl;
                    options = [ "NOPASSWD" ];
                }];
            }
        ];
    })
]
