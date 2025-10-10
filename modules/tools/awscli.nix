{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.tools.awscli;
in {
    options.modules.tools.awscli = { enable = mkEnableOption "awscli"; };
    config = mkIf cfg.enable {
        sops.secrets."aws/credentials".path = "/home/${config.home.username}/.aws/credentials";
        sops.secrets."aws/config".path = "/home/${config.home.username}/.aws/config";

        programs.awscli = {
            enable = true;
        };

        # Auto-renewal of AWS CodeArtifact PyPI credentials
        systemd.user.services.codeartifact-renewal = {
            Unit = {
                Description = "Renew AWS CodeArtifact PyPI credentials";
            };
            Service = {
                Type = "oneshot";
                ExecStart = "${pkgs.writeShellScript "renew-codeartifact" ''
                    # Source zsh env file and activate conda base
                    source "${config.xdg.configHome}/zsh/.zshenv";
                    conda activate base
                    # Run aws codeartifact login
                    ${config.programs.awscli.package}/bin/aws codeartifact login --tool pip --repository pypi-store --domain $CODEARTIFACT_DOMAIN --domain-owner $ACCOUNT_ID --region $REGION
                ''}";
                EnvironmentFile = "${config.xdg.configHome}/.env";
            };
        };

        systemd.user.timers.codeartifact-renewal = {
            Unit = {
                Description = "Timer for AWS CodeArtifact credential renewal";
            };
            Timer = {
                OnBootSec = "1min";
                OnUnitActiveSec = "11h";
                Persistent = true;
            };
            Install = {
                WantedBy = [ "timers.target" ];
            };
        };
    };
}
