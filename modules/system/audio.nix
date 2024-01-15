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
    services.pipewire = {
        audio.enable = false;
        alsa.enable = false;
        alsa.support32Bit = false;
        pulse.enable = false;
    };
}
