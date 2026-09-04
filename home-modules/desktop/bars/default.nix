{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.desktop.bars;
    noctaliaBarEnabled = (config.modules.desktop.shells.noctalia.enable or false)
        && (config.modules.desktop.shells.noctalia.components.bar or false);
    barPriorities = [ "noctalia" "waybar" ];
in {
    imports = [
        ./waybar/waybar.nix
    ];
    
    options.modules.desktop.bars = {
        default = mkOption {
            type = types.nullOr (types.enum barPriorities);
            default = null;
            internal = true;
        };
    };
    
    config = {
        modules.desktop.bars.default = utils.selectDefault {
            cfg = cfg // {
                noctalia.enable = noctaliaBarEnabled;
            };
            priorities = barPriorities;
        };

        home.packages = mkIf (config.modules.desktop.bars.default != null) [
            (pkgs.writeShellScriptBin "bar-restart" (
                if config.modules.desktop.bars.default == "noctalia" then
                    "exec noctalia-restart"
                else if config.modules.desktop.bars.default == "waybar" then
                    ''
                    pkill -x waybar >/dev/null 2>&1 || true
                    exec waybar
                    ''
                else
                    "true"
            ))
        ];

        assertions = [{
            assertion = !(cfg.waybar.enable && noctaliaBarEnabled);
            message = "Only one of modules.desktop.bars.waybar and modules.desktop.shells.noctalia (bar component) can be enabled";
        }];
    };
}
