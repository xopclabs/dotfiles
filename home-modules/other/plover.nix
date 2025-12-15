{ inputs, pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.other.plover;
in {
    options.modules.other.plover = { enable = mkEnableOption "plover"; };
    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            (inputs.plover.packages.${pkgs.stdenv.hostPlatform.system}.plover.withPlugins (
                ps: with ps; [ 
                    plover-lapwing-aio 
                    plover-machine-hid
                    plover-auto-reconnect-machine
                ] 
            ))
        ];
    };
}
