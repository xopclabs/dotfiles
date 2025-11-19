{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.cli.zoxide;

in {
    options.modules.cli.zoxide = { enable = mkEnableOption "zoxide"; };
    config = mkIf cfg.enable {
        programs.zoxide = {
            enable = true;
            enableZshIntegration = true;
            options = [
                "--cmd cd"
            ];
        };
    };
} 