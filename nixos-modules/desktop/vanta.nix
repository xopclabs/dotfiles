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

    exposeProductUuid = pkgs.writeShellApplication {
        name = "vanta-expose-product-uuid";
        runtimeInputs = [ pkgs.coreutils pkgs.util-linux ];
        text = ''
            src=/sys/devices/virtual/dmi/id
            dst=/run/vanta-dmi-id
            store=/var/lib/vanta/product_uuid

            if [ "$(findmnt -n -o SOURCE "$src" 2>/dev/null || true)" = "$dst" ]; then
                exit 0
            fi
            if [ -e "$src/product_uuid" ]; then
                exit 0
            fi

            mkdir -p "$dst" /var/lib/vanta
            chmod 755 "$dst"

            for f in "$src"/*; do
                [ -f "$f" ] || continue
                base=$(basename "$f")
                case "$base" in
                    uevent) continue ;;
                esac
                mode=$(stat -c '%a' "$f")
                if cat "$f" > "$dst/$base" 2>/dev/null; then
                    chmod "$mode" "$dst/$base"
                else
                    rm -f "$dst/$base"
                fi
            done

            ${optionalString (cfg.productUuid != null) ''
                printf '%s\n' ${escapeShellArg cfg.productUuid} > "$store"
            ''}
            ${optionalString (cfg.productUuid == null) ''
                if [ ! -s "$store" ]; then
                    mid=$(tr -d '[:space:]' < /etc/machine-id)
                    if [ ''${#mid} -ne 32 ]; then
                        echo "vanta-expose-product-uuid: /etc/machine-id is not 32 hex chars" >&2
                        exit 1
                    fi
                    printf '%s-%s-%s-%s-%s\n' \
                        "''${mid:0:8}" "''${mid:8:4}" "''${mid:12:4}" \
                        "''${mid:16:4}" "''${mid:20:12}" > "$store"
                fi
            ''}
            chmod 600 "$store"

            install -m0400 "$store" "$dst/product_uuid"
            mount --bind "$dst" "$src"
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

        productUuid = mkOption {
            type = types.nullOr types.str;
            default = null;
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

        systemd.services.vanta-dmi-uuid = {
            description = "Expose a stable DMI product_uuid for Vanta";
            wantedBy = [ "multi-user.target" ];
            before = [ "vanta.service" ];
            unitConfig.ConditionPathIsDirectory = "/sys/devices/virtual/dmi/id";
            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = getExe exposeProductUuid;
                ExecStop = getExe (pkgs.writeShellApplication {
                    name = "vanta-hide-product-uuid";
                    runtimeInputs = [ pkgs.util-linux ];
                    text = ''
                        src=/sys/devices/virtual/dmi/id
                        if [ "$(findmnt -n -o SOURCE "$src" 2>/dev/null || true)" = /run/vanta-dmi-id ]; then
                            umount "$src"
                        fi
                    '';
                });
            };
        };

        systemd.services.vanta = {
            after = [ "vanta-dmi-uuid.service" ];
            wants = [ "vanta-dmi-uuid.service" ];
            serviceConfig.ExecStartPre = mkBefore [
                (getExe writeVantaConfig)
            ];
        };
    };
}
