# Generic seed hardware config for the Ryzen 7 H255 mini PC.
# Regenerate on the machine after install with nixos-generate-config and merge if needed.
{ config, lib, pkgs, modulesPath, ... }:

{
    imports = [
        (modulesPath + "/installer/scan/not-detected.nix")
    ];

    boot.initrd.availableKernelModules = [
        "nvme"
        "xhci_pci"
        "usbhid"
        "usb_storage"
        "sd_mod"
        "amdgpu"
    ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [
        "kvm-amd"
        "amdgpu"
    ];
    boot.extraModulePackages = [ ];

    networking.useDHCP = lib.mkDefault true;

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
