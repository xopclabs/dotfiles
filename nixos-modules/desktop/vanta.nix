{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.desktop.vanta;

    writeVantaConfig = pkgs.writeShellApplication {
        name = "vanta-write-config";
        runtimeInputs = [ pkgs.coreutils pkgs.jq ];
        text = ''
            conf=/etc/vanta.conf
            key=$(tr -d '\r\n' < ${config.sops.secrets."vanta/key".path})
            ownerEmail=$(tr -d '\r\n' < ${config.sops.secrets."vanta/email".path})

            if [ -f "$conf" ] && grep -qF "$key" "$conf" && grep -qF "$ownerEmail" "$conf"; then
                exit 0
            fi

            nonce=$(date +%s%3N)
            umask 077
            jq -cn \
                --arg key "$key" \
                --arg ownerEmail "$ownerEmail" \
                --arg region "${cfg.region}" \
                --argjson nonce "$nonce" \
                '{"ACTIVATION_REQUESTED_NONCE":$nonce,"AGENT_KEY":$key,"OWNER_EMAIL":$ownerEmail,"REGION":$region,"NEEDS_OWNER":true}' \
                > "$conf"
            chmod 600 "$conf"
            chown root:root "$conf"
        '';
    };
in
{
    options.desktop.vanta = {
        enable = mkEnableOption "Vanta security monitoring agent";

        region = mkOption {
            type = types.enum [ "us" "eu" "aus" ];
            default = "us";
            description = "Vanta data region";
        };
    };

    config = mkIf cfg.enable {
        sops.secrets."vanta/key" = {
            path = "/etc/vanta-key";
            mode = "0600";
        };

        sops.secrets."vanta/email" = {
            path = "/etc/vanta-email";
            mode = "0600";
        };

        services.vanta = {
            enable = true;
            # The upstream module needs a string value but would render it into
            # the Nix store. This non-sensitive placeholder is bypassed by the
            # preceding initializer, which writes the real value from sops.
            ownerEmail = "configured-via-sops";
            region = cfg.region;
            keyFile = config.sops.secrets."vanta/key".path;
        };

        systemd.services.vanta.serviceConfig.ExecStartPre = mkBefore [
            (getExe writeVantaConfig)
        ];
    };
}
