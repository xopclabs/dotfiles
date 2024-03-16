{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.sops;
in {
    options.modules.sops = { enable = mkEnableOption "sops"; };
    config = mkIf cfg.enable {
        sops = {
            defaultSopsFile = ../../secrets.yaml;
            age.sshKeyPaths = [ "/home/xopc/.ssh/id_ed25519" ];
        };
    };
}
