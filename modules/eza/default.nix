{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.eza;

in {
    options.modules.eza = { enable = mkEnableOption "eza"; };
    config = mkIf cfg.enable {
        programs.eza = {
            enable = true;
            enableZshIntegration = true;
            icons = "always";
            colors = "always";
            git = true;
            extraOptions = [
                "--group-directories-first"
                "--header"
            ];
        };
    };
} 