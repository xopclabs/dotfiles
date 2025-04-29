{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.tools.btop;
in {
    options.modules.tools.btop = { enable = mkEnableOption "btop"; };
    config = mkIf cfg.enable {
        programs.btop = {
            enable = true;
            settings = {
                color_theme = "TTY";
                vim_keys = true;
                rounded_corners = false;
                shown_boxes = "proc cpu mem";
                update_ms = 2000;
                graph_symbol = "braille";
                proc_sorting = "memory";
                temp_scale = "celsius";
                show_battery = true;
                use_fstab = true;
            };
        };
    };
} 
