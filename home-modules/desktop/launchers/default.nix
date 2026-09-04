{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.desktop.launchers;
    noctaliaLauncherEnabled = (config.modules.desktop.shells.noctalia.enable or false)
        && (config.modules.desktop.shells.noctalia.components.launcher or false);
    launcherPriorities = [ "noctalia" "tofi" ];
in {
    imports = [
        ./tofi.nix
    ];
    
    options.modules.desktop.launchers = {
        default = mkOption {
            type = types.nullOr (types.enum launcherPriorities);
            default = null;
            internal = true;
        };
    };
    
    config = {
        modules.desktop.launchers.default = utils.selectDefault {
            cfg = cfg // {
                noctalia.enable = noctaliaLauncherEnabled;
            };
            priorities = launcherPriorities;
        };

        home.packages = mkIf (config.modules.desktop.launchers.default != null) [
            (pkgs.writeShellScriptBin "launcher-drun" (
                if config.modules.desktop.launchers.default == "noctalia" then
                    "exec noctalia msg panel-toggle launcher"
                else if config.modules.desktop.launchers.default == "tofi" then
                    "exec systemd-run --user $(tofi-drun)"
                else
                    "true"
            ))
        ];

        assertions = [{
            assertion = !(cfg.tofi.enable && noctaliaLauncherEnabled);
            message = "Only one of modules.desktop.launchers.tofi and modules.desktop.shells.noctalia (launcher component) can be enabled";
        }];
    };
}
