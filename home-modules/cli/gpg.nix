{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.cli.gpg;

in {
    options.modules.cli.gpg = { enable = mkEnableOption "gpg"; };
    config = mkIf cfg.enable {
        programs.gpg = {
            enable = true;
        };

        # Fix pass
        services.gpg-agent = {
            enable = true;
            pinentryFlavor = "qt";
        };
    };
}
