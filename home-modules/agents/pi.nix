{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.agents.pi;

in {
    options.modules.agents.pi = { enable = mkEnableOption "pi"; };
    config = mkIf cfg.enable {
        programs.pi-coding-agent = {
            enable = true;
        };
    };
}
