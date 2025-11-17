{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.ddns;
    
    # Create a service for each provider
    mkDdnsService = providerName: providerCfg: {
        "ddns-update-${providerName}" = {
            description = "DDNS Update Service for ${providerName}";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];

            serviceConfig = {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "ddns-update-${providerName}" ''
                    # Read the update URL from the secret file
                    UPDATE_URL=$(cat ${config.sops.secrets."ddns/${providerName}/url".path})
                    echo "[${providerName}] Update URL: $UPDATE_URL"

                    # Get current IP address and replace placeholder
                    CURRENT_IP=$(${pkgs.curl}/bin/curl -s https://ifconfig.me)
                    echo "[${providerName}] Current IP: $CURRENT_IP"

                    # Replace {IP} placeholder in URL with current IP using sed
                    UPDATE_URL=$(echo "$UPDATE_URL" | sed "s/{IP}/$CURRENT_IP/")
                    echo "[${providerName}] Updated Update URL: $UPDATE_URL"

                    # Perform the update
                    RESPONSE=$(${pkgs.curl}/bin/curl -s "$UPDATE_URL")
                    echo "[${providerName}] DDNS Update Response: $RESPONSE"

                    # Check for common success indicators
                    if [[ "$RESPONSE" =~ (good|nochg|OK|Updated|SUCCESS) ]]; then
                        echo "[${providerName}] Successfully updated DDNS"
                        exit 0
                    else
                        echo "[${providerName}] Warning: Unexpected response (might still be successful)"
                        # Don't fail on unexpected responses as some providers return minimal output
                        exit 0
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
        };
    
    # Create a timer for each provider
    mkDdnsTimer = providerName: providerCfg: {
        "ddns-update-${providerName}" = {
            description = "Timer for DDNS Update Service (${providerName})";
            wantedBy = [ "timers.target" ];
            
            timerConfig = {
                OnBootSec = providerCfg.bootDelay;
                OnUnitActiveSec = providerCfg.updateInterval;
                Unit = "ddns-update-${providerName}.service";
            };
        };
    };
    
    # Create secrets for each provider
    mkDdnsSecret = providerName: providerCfg: {
        "ddns/${providerName}/url" = {
            sopsFile = ../secrets/hosts/${config.metadata.hostName}.yaml;
            owner = "root";
            mode = "0400";
        };
    };
in
{
    options.homelab.ddns = {
        enable = mkEnableOption "Dynamic DNS update service";
        
        providers = mkOption {
            type = types.attrsOf (types.submodule {
                options = {
                    updateInterval = mkOption {
                        type = types.str;
                        default = "15min";
                        description = "How often to update DDNS for this provider";
                    };
                    
                    bootDelay = mkOption {
                        type = types.str;
                        default = "5min";
                        description = "Delay after boot before first update for this provider";
                    };
                };
            });
            default = {};
            description = ''
                DDNS providers to configure. Each provider should have a corresponding
                secret at ddns/{provider-name} containing the full update URL.
                
                Use {IP} placeholder in the URL if the provider requires explicit IP setting.
                The placeholder will be replaced with the auto-detected IP address.
                
            '';
        };
    };
    
    config = mkIf cfg.enable {
        # Create secrets for all providers
        sops.secrets = mkMerge (mapAttrsToList mkDdnsSecret cfg.providers);

        # Create services for all providers
        systemd.services = mkMerge (mapAttrsToList mkDdnsService cfg.providers);

        # Create timers for all providers
        systemd.timers = mkMerge (mapAttrsToList mkDdnsTimer cfg.providers);
    };
}

