{ config, pkgs, inputs, ... }:

{
    # Wifi
    networking = {
        networkmanager = {
            enable = true;
            dns = "systemd-resolved";
        };
    };
    services.resolved.enable = true;
}
