{ config, pkgs, inputs, ... }:

{
    # Sound
    sound = {
        enable = true;
    };
    hardware.pulseaudio = {
        enable = true;
        support32Bit = true;
        extraConfig = "load-module module-bluetooth-policy auto_switch=2";
    };
    services.pipewire = {
        audio.enable = false;
        alsa.enable = false;
        alsa.support32Bit = false;
        pulse.enable = false;
    };
}
