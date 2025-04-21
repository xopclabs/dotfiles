{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/adc328f5-2abc-4a1b-a1ce-9ef2d2c64d62";
      fsType = "ext4";
    };

  boot.initrd.luks.devices."luks-b08ef83e-d98d-4ca7-9c11-c2201d2bfd07".device = "/dev/disk/by-uuid/b08ef83e-d98d-4ca7-9c11-c2201d2bfd07";
  boot.initrd.luks.devices."luks-92b47c8f-c7df-4219-8e0e-2e1728fd5429".device = "/dev/disk/by-uuid/92b47c8f-c7df-4219-8e0e-2e1728fd5429";

  fileSystems."/boot" =
    { device = "/dev/disk/by-partuuid/47e1bdc3-dc4e-4529-b8ac-902ba37873ab";
      fsType = "vfat";
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/66144cb7-0666-48fb-a677-26d9c7d2c7f5"; }
    ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp2s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
