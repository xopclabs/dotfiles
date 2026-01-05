{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.immich;
in
{
    options.homelab.immich = {
        enable = mkEnableOption "Immich photo management";

        subdomain = mkOption {
            type = types.str;
            description = "Subdomain for Immich";
        };

        openFirewall = mkEnableOption "Open firewall for Immich";

        mediaLocation = mkOption {
            type = types.str;
            default = config.metadata.selfhost.storage.media.picturesDir;
            description = "Path to store Immich photos and media";
        };

        machineLearning = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable machine learning for face/object detection";
            };
        };

        hardwareAcceleration = {
            enable = mkOption {
                type = types.bool;
                default = false;
                description = "Enable hardware-accelerated video transcoding";
            };
            devices = mkOption {
                type = types.listOf types.str;
                default = [];
                example = [ "/dev/dri/renderD128" ];
                description = "Hardware acceleration device paths for video transcoding";
            };
        };
    };

    config = mkIf cfg.enable {
        services.immich = {
            enable = true;
            openFirewall = cfg.openFirewall;
            mediaLocation = cfg.mediaLocation;
            group = "users";
            machine-learning.enable = cfg.machineLearning.enable;
            # Hardware acceleration devices (empty list = PrivateDevices, null = all devices)
            accelerationDevices = mkIf cfg.hardwareAcceleration.enable (
                if cfg.hardwareAcceleration.devices != []
                then cfg.hardwareAcceleration.devices
                else null  # Allow access to all devices
            );
        };

        # Add metadata.user to video/render groups for hardware acceleration
        users.users.${config.metadata.user}.extraGroups = mkIf cfg.hardwareAcceleration.enable [ "video" "render" ];

        # Create media directory and ensure permissions (metadata.user, users group)
        systemd.tmpfiles.rules = [
            "d ${cfg.mediaLocation} 0777 ${config.metadata.user} users -"
            "Z ${cfg.mediaLocation} 0777 ${config.metadata.user} users -"
        ];

        # Register with Traefik (use localhost - Immich binds to IPv6 ::1 by default)
        # Uses defaultTransport for longer upload timeouts
        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "immich";
                subdomain = cfg.subdomain;
                backendUrl = "http://[::1]:${toString config.services.immich.port}";
                serversTransport = "defaultTransport";
            }
        ];

        # Register with Glance dashboard
        homelab.glance.services = mkIf config.homelab.glance.enable [
            {
                title = "Immich";
                subdomain = cfg.subdomain;
                icon = "si:immich";
                group = "Services";
            }
        ];
    };
}

