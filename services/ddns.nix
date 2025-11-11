{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.services.ddns;
in
{
    options.services.ddns = {
        enable = mkEnableOption "Dynamic DNS update service";
        
        updateInterval = mkOption {
            type = types.str;
            default = "15min";
            description = "How often to update DDNS";
        };
        
        bootDelay = mkOption {
            type = types.str;
            default = "5min";
            description = "Delay after boot before first update";
        };
    };
    
    config = mkIf cfg.enable {
        sops.secrets.ddns = {
            sopsFile = ../secrets/hosts/homelab.yaml;
            owner = "root";
            mode = "0400";
        };

        # No-IP DDNS Update Service
        systemd.services.ddns-update = {
            description = "No-IP Dynamic DNS Update Service";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];

            serviceConfig = {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "ddns-update" ''
                    #!/usr/bin/env bash
                    set -euo pipefail

                    # Read credentials from sops secret file
                    # Format: username:password:hostname
                    CREDENTIALS=$(cat ${config.sops.secrets.ddns.path})
                    USERNAME=$(echo "$CREDENTIALS" | cut -d: -f1)
                    PASSWORD=$(echo "$CREDENTIALS" | cut -d: -f2)
                    HOSTNAME=$(echo "$CREDENTIALS" | cut -d: -f3)

                    # Get current IP address
                    CURRENT_IP=$(${pkgs.curl}/bin/curl -s https://api.ipify.org)

                    # Update No-IP with the current IP
                    RESPONSE=$(${pkgs.curl}/bin/curl -s -u "$USERNAME:$PASSWORD" \
                        "https://dynupdate.no-ip.com/nic/update?hostname=$HOSTNAME&myip=$CURRENT_IP")

                    echo "No-IP DDNS Update Response: $RESPONSE"

                    # Check for success (response should start with "good" or "nochg")
                    if [[ "$RESPONSE" =~ ^(good|nochg) ]]; then
                        echo "Successfully updated DDNS for $HOSTNAME to $CURRENT_IP"
                        exit 0
                    else
                        echo "Failed to update DDNS. Response: $RESPONSE"
                        exit 1
                    fi
                '';

                # Security hardening
                DynamicUser = false;
                PrivateTmp = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                NoNewPrivileges = true;
                PrivateDevices = true;
                ProtectKernelTunables = true;
                ProtectKernelModules = true;
                ProtectControlGroups = true;
                RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
                RestrictNamespaces = true;
                LockPersonality = true;
                RestrictRealtime = true;
                RestrictSUIDSGID = true;
                RemoveIPC = true;
                PrivateMounts = true;
            };
        };

        # Timer to run the DDNS update service periodically
        systemd.timers.ddns-update = {
            description = "Timer for DDNS Update Service";
            wantedBy = [ "timers.target" ];
            
            timerConfig = {
                OnBootSec = cfg.bootDelay;
                OnUnitActiveSec = cfg.updateInterval;
                Unit = "ddns-update.service";
            };
        };
    };
}

