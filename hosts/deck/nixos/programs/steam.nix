{ config, pkgs, inputs, ... }:

{
    # Jovian NixOS configuration for Steam Deck
    jovian = {
        # Steam configuration
        steam = {
            enable = true;
            autoStart = true;
            desktopSession = "hyprland-uwsm";  # UWSM-managed Hyprland session
            user = "xopc";
        };

        devices.steamdeck.enable = true;
        steamos.useSteamOSConfig = true;

        # Decky Loader for plugins
        decky-loader = {
            enable = true;
        };
    };

    # But keep protontricks available
    environment.systemPackages = with pkgs; [
        protontricks
    ];

    hardware.xone.enable = true;
}
