{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.desktop.p81;
    perimeter81-unwrapped = pkgs.callPackage ./package.nix {};
    perimeter81 = pkgs.callPackage ./fhsenv.nix { inherit perimeter81-unwrapped; };
    p81-reset = pkgs.callPackage ./reset.nix {};
in
{
    imports = [ ./split-dns.nix ];

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

            # The vendor GUI hardcodes /opt/Perimeter81/perimeter81 when it writes its
            # own ~/.config/autostart/perimeter81.desktop entry (e.g. "launch at login").
            # That path only exists inside the FHS sandbox, not on the host, so the
            # generated autostart entry (and any desktop shortcut the app writes itself)
            # fails with "Exec binary does not exist". Backfill it with a symlink to our
            # wrapped launcher so those vendor-written entries work unmodified.
            "d /opt/Perimeter81 0755 root root -"
            "L+ /opt/Perimeter81/perimeter81 - - - - ${perimeter81}/bin/perimeter81"
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
                # The daemon's own "stop" subcommand has been observed to *never* return
                # gracefully in practice (every stop on record hits the full timeout), so
                # a long grace period only slows down restarts, reboots and suspend/resume
                # recovery without ever paying off. Give it a short chance, then let
                # systemd's normal KillMode=control-group finish the job.
                ExecStop = pkgs.writeShellScript "p81-stop" ''
                    set +e
                    ${pkgs.coreutils}/bin/timeout 8 ${perimeter81}/bin/p81-helper-daemon stop
                    code=$?
                    if [ "$code" -eq 124 ]; then
                        echo "p81-stop: graceful stop timed out after 8s, systemd will force-kill the cgroup" >&2
                    fi
                    exit 0
                '';
                # Deterministic cleanup after every stop (manual, restart, or crash), not
                # just via the manual `p81-reset` fallback. This is what previously left
                # state behind across restarts/suspend cycles.
                ExecStopPost = pkgs.writeShellScript "p81-stop-cleanup" ''
                    set +e
                    ${pkgs.coreutils}/bin/rm -f \
                        /tmp/app.p81helper \
                        /run/p81-native-helper-parent.socket \
                        /run/p81-native-helper-child.socket \
                        /var/run/p81-native-helper-parent.socket \
                        /var/run/p81-native-helper-child.socket
                    if ${pkgs.iproute2}/bin/ip link show tun0 &>/dev/null; then
                        ${pkgs.iproute2}/bin/ip route flush dev tun0 2>/dev/null || true
                        ${pkgs.iproute2}/bin/ip link delete tun0 2>/dev/null || true
                    fi
                    exit 0
                '';
                KillMode = "control-group";
                Restart = "always";
                RestartSec = "5";
                TimeoutStopSec = "20";
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
                    ${pkgs.coreutils}/bin/sleep ${toString cfg.sleepResumeDelaySec}
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
