{ config, pkgs, inputs, ... }:

{
    # Sound
    /*
    sound = {
        enable = true;
    };
    hardware.pulseaudio = {
        enable = true;
        support32Bit = true;
        extraConfig = "load-module module-bluetooth-policy auto_switch=2";
    };
    */
    security.rtkit.enable = true;
    services.pipewire = {
        enable = true;
        audio.enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        jack.enable = true;
        pulse.enable = true;
    };
    services.pipewire.wireplumber.extraConfig = {
        "monitor.bluez.properties" = {
            "bluez5.enable-sbc-xq" = true;
            "bluez5.enable-msbc" = true;
            "bluez5.enable-hw-volume" = true;
            "bluez5.roles" = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ];
        };
    };
}
