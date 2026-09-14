{ config, lib, ... }:

with lib;
let
    cfg = config.homelab.telemetry;
in
{
    config = mkIf cfg.enable {
        users.groups.telemetry = {};
        users.users.telemetry = {
            isSystemUser = true;
            group = "telemetry";
        };

        homelab.postgres = {
            enable = true;
            databases = [ "telemetry" ];
            ensureUsers = [{ name = "telemetry"; }];
        };
    };
}
