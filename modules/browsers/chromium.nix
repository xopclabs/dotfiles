{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.browsers.chromium;

in {
    options.modules.browsers.chromium = { enable = mkEnableOption "chromium"; };
    config = mkIf cfg.enable {
        programs.chromium = {
            enable = true;
            package = pkgs.ungoogled-chromium;
        };
    };
} 