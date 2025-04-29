{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.fileManagers.ranger;
in {
    options.modules.fileManagers.ranger = { enable = mkEnableOption "ranger"; };
    config = mkIf cfg.enable {
        programs.ranger = {
            enable = true;
            extraConfig = "set preview_images true";
        };
        home.packages = with pkgs; [
            w3m
        ];
    };
}
