{ config, lib, ... }:

with lib;
let
    cfg = config.desktop.lact;
in
{
    options.desktop.lact = {
        enable = mkEnableOption "LACT AMD GPU tweaking";
    };

    config = mkIf cfg.enable {
        services.lact.enable = true;
        hardware.amdgpu.overdrive.enable = true;
    };
}
