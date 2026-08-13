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

    # nixpkgs makes docker.service Require this generator. A driver/library
    # mismatch (new userspace, old kernel module) fails the unit, which fails
    # docker, which fails `nh os switch`, which then never commits the
    # generation to GRUB — reboot cannot load the matching module.
    systemd.services.nvidia-container-toolkit-cdi-generator.serviceConfig.SuccessExitStatus = [ 1 ];

    users.users.jellyfin.extraGroups = [ "render" "video" ];

    environment.systemPackages = with pkgs; [
        nvtopPackages.nvidia
    ];
}
