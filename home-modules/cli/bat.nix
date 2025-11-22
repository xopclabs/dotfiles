{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.cli.bat;

in {
    options.modules.cli.bat = { enable = mkEnableOption "bat"; };
    config = mkIf cfg.enable {
        programs.bat = {
            enable = true;
            config = {
                style = "numbers,changes,header";
            };
            extraPackages = with pkgs.bat-extras; [
                batdiff
                batman
                # batgrep isn't working as of 2025-10-24
                # batgrep
                batwatch
            ];
        };
        programs.zsh.shellAliases.cat = "bat --paging=never --style=plain";
    };
} 
