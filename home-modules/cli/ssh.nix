{ pkgs, lib, config, ... }:
with lib;
let 
    cfg = config.modules.cli.ssh;
in {
    options.modules.cli.ssh = { enable = mkEnableOption "ssh"; };
    config = mkIf cfg.enable {
        sops.secrets."ssh/config".path = "/home/${config.home.username}/.ssh/hosts_config";

        # Hack to fix SSH warnings/errors due to a file permissions check in VSCode, Cursor
        home.file.".ssh/config" = {
            target = ".ssh/config_source";
            onChange = ''cat .ssh/config_source > .ssh/config && chmod 400 .ssh/config'';
        };

        programs.ssh = {
            enable = true;
            includes = [ "hosts_config" ];
            extraConfig = ''
                StrictHostKeyChecking no
                ServerAliveInterval 10
                ServerAliveCountMax 120
            '';
        };
    };
}
