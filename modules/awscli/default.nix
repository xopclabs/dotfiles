{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.awscli;
in {
    options.modules.awscli = { enable = mkEnableOption "awscli"; };
    config = mkIf cfg.enable {
        sops.secrets."aws/credentials".path = "/home/xopc/.aws/credentials";
        sops.secrets."aws/config".path = "/home/xopc/.aws/config";

        programs.awscli = {
            enable = true;
        };
    };
}
