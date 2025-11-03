{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.tools.git;
    name = "xopclabs";
    email = "b9fyg5ei@duck.com";
in {
    options.modules.tools.git = { 
        enable = mkEnableOption "git"; 
        # Signing key with, defaults to ~/.ssh/id_ed25519
        signingKey = mkOption {
            type = types.str;
            default = "${config.home.homeDirectory}/.ssh/id_ed25519";
            description = "The SSH key to use for signing commits";
        };
    };
    config = mkIf cfg.enable {
        programs.git = {
            enable = true;
            settings = {
                push.autoSetupRemote = true; 
                user = {
                    name = name;
                    email = email;
                };
            };
            signing = {
                format = "ssh";
                signByDefault = true;
                key = cfg.signingKey;
            };
        };
    };
}
