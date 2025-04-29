{ inputs, pkgs, config, lib, ... }:

with lib;
let
    cfg = config.modules.browsers;
    browserPriorities = [ "firefox" "zen" ];
    getDefaultBrowser = priorities: let
        enabledBrowsers = filter (browser: cfg.${browser}.enable or false) priorities;
    in
        if enabledBrowsers == [] then null else head enabledBrowsers;
in {
    imports = [
        ./firefox/firefox.nix
        ./zen/zen.nix
    ];
    
    options.modules.browsers = {
        default = mkOption {
            type = types.nullOr (types.enum browserPriorities);
            default = null;
            internal = true;
        };
    };
    
    config = {
        modules.browsers.default = getDefaultBrowser browserPriorities;
    };
}