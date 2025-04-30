{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.MODULEGROUP.PROGRAM;

in {
    options.modules.MODULEGROUP.PROGRAM = { enable = mkEnableOption "PROGRAM"; };
    config = mkIf cfg.enable {

    };
}
