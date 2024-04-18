{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.nh;

in {
    options.modules.nh = { enable = mkEnableOption "nh"; };
    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            nh
        ];
    };
}
