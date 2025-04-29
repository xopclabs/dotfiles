{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.tools.awscli;
in {
    options.modules.tools.awscli = { enable = mkEnableOption "awscli"; };
    config = mkIf cfg.enable {
        sops.secrets."aws/credentials".path = "/home/${config.home.username}/.aws/credentials";
        sops.secrets."aws/config".path = "/home/${config.home.username}/.aws/config";

        programs.awscli = {
            enable = true;
        };
    };
}
