{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.fileManagers.nautilus;
in {
    options.modules.fileManagers.nautilus = { enable = mkEnableOption "nautilus"; };
    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            nautilus
        ];
    };
}
