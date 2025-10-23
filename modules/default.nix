{ inputs, pkgs, config, lib, ... }:

with lib;
let
    # Select a default item based on priorities when multiple items can be enabled
    selectDefault = { cfg, priorities, itemField ? "enable" }: 
    let
        enabledItems = filter (item: cfg.${item}.${itemField} or false) priorities;
    in
        if enabledItems == [] then null else head enabledItems;
    
    # Safely reference potentially null values
    # Usage: safeRef config.modules.browsers.default "firefox"
    # Returns: The value if not null, or the fallback
    safeRef = value: fallback:
        if value != null then value else fallback;
    
    # Safely reference potentially null values with string conversion/formatting
    # Usage: safeRefStr config.modules.browsers.default (x: "${x}.desktop") "firefox.desktop"
    # Returns: The formatted value if not null, or the fallback
    safeRefStr = value: formatter: fallback:
        if value != null then formatter value else fallback;
in
{
    home.stateVersion = "24.05";
    imports = [
        ./browsers
        ./file_managers
        ./editors
        ./cli
        ./tools
        ./terminals
        ./gui
        ./desktop
        ./players
        ./packages
        ./theming
        ./other
    ];

    # Export the utility functions
    _module.args = {
        utils = {
            inherit selectDefault safeRef safeRefStr;
        };
    };

}
