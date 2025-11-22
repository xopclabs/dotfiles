{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.desktop.steam;
in
{
    options.desktop.steam = {
        enable = mkEnableOption "Steam and gaming configuration";

        jovian = {
            enable = mkEnableOption "Jovian NixOS Steam Deck configuration";

            autoStart = mkOption {
                type = types.bool;
                default = true;
                description = "Auto-start Steam on boot";
            };

            desktopSession = mkOption {
                type = types.str;
                default = "hyprland-uwsm";
                description = "Desktop session to use";
            };

            deckyLoader = {
                enable = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Enable Decky Loader for Steam Deck plugins";
                };

                user = mkOption {
                    type = types.str;
                    default = "decky";
                    description = "User for Decky Loader";
                };
            };
        };

        extraPackages = mkOption {
            type = types.bool;
            default = true;
            description = "Install extra gaming packages (protontricks, protonup-ng)";
        };

        hardware = {
            xoneSupport = mkOption {
                type = types.bool;
                default = true;
                description = "Enable Xbox One controller support";
            };

            joyconSupport = mkOption {
                type = types.bool;
                default = true;
                description = "Enable Nintendo Joy-Con support";
            };

            trackpadDesktop = mkOption {
                type = types.bool;
                default = true;
                description = "Enable trackpad support in desktop mode";
            };
        };
    };

    config = mkIf cfg.enable {
        # Jovian NixOS configuration
        jovian = mkIf cfg.jovian.enable {
            steam = {
                enable = true;
                autoStart = cfg.jovian.autoStart;
                desktopSession = cfg.jovian.desktopSession;
                user = config.metadata.user;
            };

            devices.steamdeck.enable = true;
            steamos.useSteamOSConfig = true;

            decky-loader = mkIf cfg.jovian.deckyLoader.enable {
                enable = true;
                user = cfg.jovian.deckyLoader.user;
            };
        };

        # Extra gaming packages
        environment.systemPackages = mkIf cfg.extraPackages (with pkgs; [
            protontricks
            protonup-ng
        ]);

        # Hardware support
        hardware.xone.enable = mkIf cfg.hardware.xoneSupport true;
        services.joycond.enable = mkIf cfg.hardware.joyconSupport true;
        programs.steam.extest.enable = mkIf cfg.hardware.trackpadDesktop true;

        # Add user to input group if trackpad support is enabled
        users.users.${config.metadata.user}.extraGroups = mkIf cfg.hardware.trackpadDesktop [ "input" ];
    };
}

