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

        devices.steamdeck = {
            enable = true;
        };
        steamos.useSteamOSConfig = true;

        # Decky Loader for plugins
        decky-loader = {
            enable = true;
            user = "decky";
        };
    };

    environment.systemPackages = with pkgs; [
        protontricks
        protonup-ng
    ];

    # Gamepad support
    hardware.xone.enable = true;
    # Joycon support
    services.joycond.enable = true;
    # Trackpad in desktop mode
    programs.steam.extest.enable = true;
    users.users.xopc.extraGroups = [ "input" ];
}
