{ config, lib, ... }:

with lib;
{
    options.metadata = {
        user = mkOption {
            type = types.str;
            description = "Main user of the system";
        };
        hostName = mkOption {
            type = types.str;
            description = "Hostname of the system";
        };
        network = {
            ipv4 = mkOption {
                type = types.str;
                default = null;
                description = "Internal IP address of the system";
            };
            defaultGateway = mkOption {
                type = types.str;
                default = null;
                description = "Default gateway of the system";
            };
        };

        hardware = {
            monitors = mkOption {
                type = types.attrsOf (types.submodule {
                    options = {
                        name = mkOption {
                            type = types.str;
                            description = "Monitor name as reported by wlr-randr or similar";
                        };
                        mode = mkOption {
                            type = types.str;
                            description = "Monitor resolution and refresh rate (e.g., '1920x1080@60')";
                        };
                        scale = mkOption {
                            type = types.float;
                            default = 1.0;
                            description = "Monitor scale factor";
                        };
                        transform = mkOption {
                            type = types.enum ["normal" "90" "180" "270" "flipped" "flipped-90" "flipped-180" "flipped-270"];
                            default = "normal";
                            description = "Monitor transformation (rotation/flipping)";
                        };
                        position = mkOption {
                            type = types.str;
                            description = "Monitor position (e.g., '0,0')";
                        };
                    };
                });
                default = null;
                description = "Hardware monitor configuration";
            };
        };
    };
}
