{ ... }:

{
    hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
    };

    # Fix controller pairing issues.
    boot.extraModprobeConfig = '' options bluetooth disable_ertm=1 '';
}
