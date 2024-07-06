{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.ssh;
in {
    options.modules.ssh = { enable = mkEnableOption "ssh"; };
    config = mkIf cfg.enable {
        sops.secrets."ssh/config".path = "/home/xopc/.ssh/hosts_config";
        sops.secrets."ssh/id_ed25519".path = "/home/xopc/.ssh/id_ed25519";
        sops.secrets."ssh/id_ed25519.pub".path = "/home/xopc/.ssh/id_ed25519.pub";

        programs.ssh = {
            enable = true;
            includes = [ "hosts_config" ];
            extraConfig = ''
                StrictHostKeyChecking no
            '';
        };
    };
}
