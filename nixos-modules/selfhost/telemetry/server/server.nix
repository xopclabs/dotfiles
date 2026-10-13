{ lib, ... }:

{
    options.homelab.telemetry.server = {
        enable = lib.mkEnableOption "MQTT telemetry storage";
        listenAddress = lib.mkOption {
            type = lib.types.str;
            default = "10.250.250.1";
            description = "Private MQTT address for telemetry senders and the ingester.";
        };
    };

    imports = [
        ./postgres.nix
        ./mosquitto.nix
        ./ingester.nix
    ];
}
