{ config, lib, ... }:

with lib;
let
    cfg = config.desktop.lact;
in
{
    options.desktop.lact = {
        enable = mkEnableOption "LACT AMD GPU tweaking";
    };

    config = mkIf cfg.enable {
        services.lact = {
            enable = true;
            settings = {
                version = 7;
                daemon = {
                    log_level = "info";
                    admin_group = "wheel";
                    disable_clocks_cleanup = false;
                };
                apply_settings_timer = 5;

                # RX9070XT GPU
                gpus."1002:7550-1002:0124-0000:03:00.0" = {
                    fan_control_enabled = false;
                    pmfw_options = {
                        zero_rpm = true;
                    };
                    power_cap = 260.0;

                    performance_level = "manual";
                    power_profile_mode_index = 6; # CUSTOM
                    custom_power_profile_mode_hueristics = [
                        # GFXCLK
                        [ 0 4 600 4 800 4587520 (0-65536) 0 ]
                        # FCLK — unchanged from BOOTUP_DEFAULT
                        [ 0 3 0 1 0 5898240 (0-6553) (0-6553) ]
                    ];
                };

                current_profile = null;
                auto_switch_profiles = false;
            };
        };
        hardware.amdgpu.overdrive.enable = true;
    };
}
