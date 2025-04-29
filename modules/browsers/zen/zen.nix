{ inputs, pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.browsers.zen;
in {
    options.modules.browsers.zen = { enable = mkEnableOption "zen"; };
    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            inputs.zen-browser.packages."x86_64-linux".specific
        ];
    };
}
