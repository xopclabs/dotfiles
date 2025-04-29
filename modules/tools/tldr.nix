{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.tools.tldr;

in {
    options.modules.tools.tldr = { enable = mkEnableOption "tldr"; };
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