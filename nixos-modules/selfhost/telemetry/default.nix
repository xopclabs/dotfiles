{ lib, ... }:

with lib;
{
    options.homelab.telemetry.enable = mkEnableOption "MQTT telemetry storage";

    imports = [
        ./postgres.nix
        ./mosquitto.nix
        ./ingester.nix
    ];
}
