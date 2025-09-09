{ config, lib, ... }:

with lib;
{
    options.hardware = {
        monitors = mkOption {
            type = types.attrsOf (types.submodule {
                options = {
                    name = mkOption {
                        type = types.str;
                        description = "Monitor name as reported by wlr-randr or similar";
                    };
                };
            });
            default = {};
            description = "Hardware monitor configuration";
        };
    };
}
