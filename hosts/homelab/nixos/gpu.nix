{ config, pkgs, lib, ... }:

{
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.graphics = {
        enable = true;
        enable32Bit = false;
    };

    hardware.nvidia = {
        open = false;
        modesetting.enable = true;

        nvidiaSettings = false;

        powerManagement.enable = false;
        powerManagement.finegrained = false;

        # Pin to the current stable branch of the proprietary driver
        package = config.boot.kernelPackages.nvidiaPackages.stable;
    };

    hardware.nvidia-container-toolkit.enable = true;

    users.users.jellyfin.extraGroups = [ "render" "video" ];

    environment.systemPackages = with pkgs; [
        nvtopPackages.nvidia
    ];
}
