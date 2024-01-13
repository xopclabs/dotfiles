{ config, pkgs, inputs, ... }:

{
    # Sound
    sound = {
        enable = true;
    };
    hardware.pulseaudio = {
        enable = true;
        support32Bit = true;
    };
    security.rtkit.enable = true;
    services.pipewire = {
        enable = false;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
    };
}
