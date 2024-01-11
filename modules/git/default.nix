{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.git;
    name = "xopclabs";
    email = "b9fyg5ei@duck.com";
in {
    options.modules.git = { enable = mkEnableOption "git"; };
    config = mkIf cfg.enable {
        programs.git = {
            enable = true;
            userName = name;
            userEmail = email;
            extraConfig = {
                github.user = name;
                push.autoSetupRemote = true; 
                credential = {
                    helper = "${pkgs.git.override {withLibsecret = true;}}/bin/git-credential-libsecret";
                    credentialStore = "secretservice";
                };
            };
        };
    };
}
