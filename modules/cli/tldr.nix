{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.cli.tldr;

in {
    options.modules.cli.tldr = { enable = mkEnableOption "tldr"; };
    config = mkIf cfg.enable {
        services.tldr-update = {
            enable = true;
            period = "daily";
        };

        programs.zsh.shellAliases = {
            mant = "tldr";
        };
    };
} 