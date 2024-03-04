{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.scripts;
in {
    options.modules.scripts = { enable = mkEnableOption "scripts"; };
    config = mkIf cfg.enable {
        home.packages = [
            maintenance sftpmpv tm freshman_start
        ];
    };
}
