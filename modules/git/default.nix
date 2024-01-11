{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.git;

in {
    options.modules.git = { enable = mkEnableOption "git"; };
    config = mkIf cfg.enable {
        programs.git = {
            enable = true;
            userName = "xopclabs";
            userEmail = "github@conv2d.com";
            extraConfig = {
                credential = {
                    helper = "${pkgs.git.override {withLibsecret = true;}}/bin/git-credential-libsecret";
                    credentialStore = "secretservice";
                };
                init = { 
                    defaultBranch = "main"; 
                    push.autoSetupRemote = true; 
                };
                core = {
                    excludesfile = "$NIXOS_CONFIG_DIR/scripts/gitignore";
                };
            };
        };
    };
}
