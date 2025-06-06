{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.browsers;
    browserPriorities = [ "firefox" "zen" "chromium" ];
in {
    imports = [
        ./firefox/firefox.nix
        ./chromium.nix
        ./zen.nix
    ];
    
    options.modules.browsers = {
        default = mkOption {
            type = types.nullOr (types.enum browserPriorities);
            default = null;
            internal = true;
        };
    };
    
    config = {
        modules.browsers.default = utils.selectDefault {
            inherit cfg;
            priorities = browserPriorities;
        };
    };
}