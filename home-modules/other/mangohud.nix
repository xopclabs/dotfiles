{ lib, config, ... }:

with lib;
let
    cfg = config.modules.other.mangohud;
    colors = config.colorScheme.palette;
in {
    options.modules.other.mangohud = {
        enable = mkEnableOption "MangoHud";

        enableSessionWide = mkOption {
            type = types.bool;
            default = false;
            description = "Enable MangoHud for every supported application in the user session.";
        };
    };

    config = mkIf cfg.enable {
        programs.mangohud = {
            enable = true;
            enableSessionWide = cfg.enableSessionWide;
            settings = {
                fps = true;
                frametime = true;
                frame_timing = true;
                gpu_stats = true;
                gpu_temp = true;
                gpu_power = true;
                gpu_mem_temp = true;
                vram = true;
                cpu_stats = true;
                cpu_temp = true;
                ram = true;
                wine = true;
                vulkan_driver = true;
                engine_version = true;
                gamemode = true;
                throttling_status = true;
                frame_count = true;

                # Match the active nix-colors/base16 palette. Keep the HUD background transparent.
                background_alpha = 0.0;
                alpha = 1.0;
                background_color = colors.base00;
                text_color = colors.base05;
                fps_color = [ colors.base0B colors.base0A colors.base08 ];
                frametime_color = colors.base0B;
                gpu_color = colors.base0B;
                gpu_load_color = [ colors.base0B colors.base0A colors.base08 ];
                vram_color = colors.base0C;
                cpu_color = colors.base0D;
                cpu_load_color = [ colors.base0B colors.base0A colors.base08 ];
                io_color = colors.base0A;
                engine_color = colors.base0E;
                wine_color = colors.base0E;
                battery_color = colors.base04;
                media_player_color = colors.base05;

                # Bigger and crisper: avoid the default outline blur and Stylix's font_scale workaround.
                font_size = 22;
                font_size_text = 22;
                font_scale = 1.0;
                no_small_font = true;
                text_outline = false;

                toggle_hud = "Shift_L+F10";
                toggle_logging = "Shift_L+F9";
                output_folder = "~/mangohud-logs";
            };
        };
    };
}
