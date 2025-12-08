{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.keepalived;
in
{
    options.homelab.keepalived = {
        enable = mkEnableOption "Keepalived VRRP for high availability";

        virtualIP = mkOption {
            type = types.str;
            description = "Virtual IP address shared between nodes";
        };

        interface = mkOption {
            type = types.str;
            description = "Network interface to bind to";
        };

        priority = mkOption {
            type = types.int;
            default = 100;
            description = "VRRP priority (higher = more likely to become master)";
        };

        virtualRouterId = mkOption {
            type = types.int;
            default = 51;
            description = "Virtual router ID (must be same on all nodes in cluster)";
        };

        authPass = mkOption {
            type = types.str;
            default = "keepalived";
            description = "Authentication password for VRRP (must be same on all nodes)";
        };
        
        trackPihole = mkOption {
            type = types.bool;
            default = config.homelab.pihole_unbound.enable;
            description = "Track Pi-hole health - failover if pihole-FTL is not running. Defaults to true if pihole_unbound is enabled.";
        };
    };
    
    config = mkIf cfg.enable {
        services.keepalived = {
            enable = true;
            
            vrrpScripts = mkIf cfg.trackPihole {
                chk_pihole = {
                    script = "${pkgs.procps}/bin/pgrep pihole-FTL";
                    interval = 5;
                    weight = -1000;
                    fall = 2;
                    rise = 1;
                    user = "root";
                    group = "root";
                };
            };

            vrrpInstances.main = {
                interface = cfg.interface;
                state = if cfg.priority >= 150 then "MASTER" else "BACKUP";
                priority = cfg.priority;
                virtualRouterId = cfg.virtualRouterId;
                virtualIps = [
                    { addr = "${cfg.virtualIP}/24"; }
                ];
                
                trackScripts = mkIf cfg.trackPihole [ "chk_pihole" ];

                extraConfig = ''
                    advert_int 1
                    authentication {
                        auth_type PASS
                        auth_pass ${cfg.authPass}
                    }
                '';
            };
        };

    };
}

