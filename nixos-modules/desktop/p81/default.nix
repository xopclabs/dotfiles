{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.desktop.p81;
    perimeter81-unwrapped = pkgs.callPackage ./package.nix {};
    perimeter81 = pkgs.callPackage ./fhsenv.nix { inherit perimeter81-unwrapped; };
    p81-reset = pkgs.callPackage ./reset.nix {};
in
{
    options.desktop.p81 = {
        enable = mkEnableOption "Perimeter81 corporate VPN support";
        sleepResumeRecovery = mkOption {
            type = types.enum [ "none" "async-restart" "async-reset" ];
            default = "async-restart";
            description = ''
                After suspend/hibernate, schedule recovery so the GUI does not sit in an
                endless "connecting" state while Wi-Fi and DNS come back.

                - `none`: do nothing automatically (use `sudo p81-reset` when stuck).
                - `async-restart`: queue a delayed `systemctl restart` via `systemd-run`
                  (does not block resume; avoids the freezes caused by a synchronous
                  restart inside system-sleep).
                - `async-reset`: same timing but runs `p81-reset` (harder flush of tun0
                  and children) if a plain restart is not enough.
            '';
        };
        sleepResumeDelaySec = mkOption {
            type = types.ints.positive;
            default = 20;
            description = ''
                Seconds to wait after resume before running sleep resume recovery (Wi-Fi
                and NetworkManager often need a moment before the helper can reconnect).
            '';
        };
        restartOnPhysicalLinkUp = mkOption {
            type = types.bool;
            default = false;
            description = ''
                When a physical interface (Wi-Fi / Ethernet) comes up, try-restart the
                helper daemon. Can help after roaming, but may bounce the VPN on flaky Wi-Fi;
                leave off unless you need it.
            '';
        };
    };

    config = mkIf cfg.enable {
        environment.systemPackages = [ perimeter81 p81-reset ];

        systemd.tmpfiles.rules = [
            "d /var/lib/p81 0755 root root -"
            "d /var/lib/p81/local 0755 root root -"
            "d /var/lib/p81/etc 0755 root root -"
        ];

        systemd.services.perimeter81-helper-daemon = {
            description = "Perimeter81 Helper Daemon";
            wants = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            requires = [ "network-online.target" ];
            after = [
                "NetworkManager.service"
                "systemd-resolved.service"
            ];

            serviceConfig = {
                ExecStartPre = pkgs.writeShellScript "p81-setup" ''
                    mkdir -p /var/lib/p81/local
                    mkdir -p /var/lib/p81/etc
                    cp /etc/resolv.conf /var/lib/p81/resolv.conf 2>/dev/null || touch /var/lib/p81/resolv.conf
                    chmod 644 /var/lib/p81/resolv.conf
                '';
                ExecStart = "${perimeter81}/bin/p81-helper-daemon";
                ExecStop = pkgs.writeShellScript "p81-stop" ''
                    set +e
                    ${pkgs.coreutils}/bin/timeout 35 ${perimeter81}/bin/p81-helper-daemon stop
                    code=$?
                    if [ "$code" -eq 124 ]; then
                        echo "p81-stop: graceful stop timed out after 35s" >&2
                    fi
                    exit 0
                '';
                Restart = "always";
                RestartSec = "5";
                TimeoutStopSec = "50";
                SyslogIdentifier = "perimeter81helper";
                User = "root";
                Group = "root";
                WorkingDirectory = "/";
            };
        };

        environment.etc = mkMerge [
            (mkIf (cfg.sleepResumeRecovery != "none") (let
                postResumeRun = pkgs.writeShellScript "p81-postresume-run" ''
                    set -euo pipefail
                    sleep ${toString cfg.sleepResumeDelaySec}
                    ${if cfg.sleepResumeRecovery == "async-reset" then ''
                        exec ${p81-reset}/bin/p81-reset
                    '' else ''
                        exec ${pkgs.systemd}/bin/systemctl restart perimeter81-helper-daemon
                    ''}
                '';
            in {
                "systemd/system-sleep/p81-resume-async" = {
                    mode = "0755";
                    source = pkgs.writeShellScript "p81-resume-async" ''
                        case "$1/$2" in
                            post/*)
                                exec ${pkgs.systemd}/bin/systemd-run --no-block \
                                    --description="Perimeter81 post-resume recovery" \
                                    ${postResumeRun}
                                ;;
                        esac
                    '';
                };
            }))
            (mkIf cfg.restartOnPhysicalLinkUp {
                "NetworkManager/dispatcher.d/99-p81-physical-up" = {
                    mode = "0755";
                    source = pkgs.writeShellScript "p81-nm-dispatcher" ''
                        set -eu
                        iface="$1"
                        action="$2"
                        [ "$action" = up ] || exit 0
                        case "$iface" in
                            tun*|wg*|lo|docker*|veth*|br-*|virbr*|zt*) exit 0 ;;
                        esac
                        case "$iface" in
                            wl*|en*|wlan*|eth*) ;;
                            *) exit 0 ;;
                        esac
                        ${pkgs.systemd}/bin/systemctl try-restart perimeter81-helper-daemon || true
                    '';
                };
            })
        ];
    };
}
