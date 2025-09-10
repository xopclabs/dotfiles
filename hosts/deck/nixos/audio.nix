{ config, pkgs, inputs, ... }:

{
    # Sound
    services.pipewire.wireplumber.extraConfig = {
        "monitor.bluez.properties" = {
            "bluez5.enable-sbc-xq" = true;
            "bluez5.enable-msbc" = true;
            "bluez5.enable-hw-volume" = true;
            "bluez5.auto-connect" = [ "a2dp_sink" "hfp_hf" "hsp_hs" "hfp_ag" "hsp_ag" "a2dp_source" ];
            "bluez5.roles" = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ];
        };
    };
}
