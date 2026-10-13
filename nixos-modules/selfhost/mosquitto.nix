{ config, lib, options, ... }:

{
    # Named listeners let consumers contribute accounts to the same socket.
    # Reuse the upstream listener type rather than maintaining another schema.
    options.homelab.mosquitto.listeners = lib.mkOption {
        type = lib.types.attrsOf options.services.mosquitto.listeners.type.nestedTypes.elemType;
        default = {};
        internal = true;
        description = "Consumer-owned MQTT listeners, merged by name.";
    };

    config = lib.mkIf config.services.mosquitto.enable {
        services.mosquitto = {
            persistence = true;
            settings = {
                autosave_interval = lib.mkDefault 60;
                max_queued_messages = lib.mkDefault 0;
                max_queued_bytes = lib.mkDefault 0;
                queue_qos0_messages = lib.mkDefault true;
            };
            listeners = lib.mapAttrsToList (_: listener: listener // {
                settings = listener.settings // { allow_anonymous = false; };
            }) config.homelab.mosquitto.listeners;
        };
    };
}
