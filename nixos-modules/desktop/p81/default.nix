{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.desktop.p81;
    perimeter81-unwrapped = pkgs.callPackage ./package.nix {};
    perimeter81 = pkgs.callPackage ./fhsenv.nix { inherit perimeter81-unwrapped; };
    p81ctl = pkgs.callPackage ./ctl.nix {};
    p81-reset = pkgs.callPackage ./reset.nix {
        inherit p81ctl;
        inherit (cfg) autoConnect connectTimeoutSec resetAttempts;
    };
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
                  restart inside system-sleep). With `autoConnect`, this escalates to
                  `p81-reset` if the tunnel does not come back after the restart.
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
        autoConnect = mkOption {
            type = types.bool;
            default = true;
            description = ''
                Bring the tunnel back up automatically instead of leaving it to a manual
                click in the GUI, both at the end of `p81-reset` and after sleep resume
                recovery.

                This drives the daemon's own control socket via `p81ctl`, so it works
                with the GUI closed and without a display. It cannot help when the agent
                is logged out, since obtaining a fresh token needs the browser flow.
            '';
        };
        connectTimeoutSec = mkOption {
            type = types.ints.positive;
            default = 45;
            description = ''
                How long `autoConnect` keeps trying per reset. Waiting for the daemon to
                boot, log in and reach its cloud channel is budgeted separately and does
                not count against this.

                This wants to be generous. A connect can be swallowed silently or refused
                by the cloud with an error the agent never handles, and both clear up on
                their own after a minute or so, so persistence works where a quick retry
                does not.
            '';
        };
        resetAttempts = mkOption {
            type = types.ints.positive;
            default = 2;
            description = ''
                How many times `p81-reset` resets the agent while trying to get the
                tunnel up, before giving up and pointing at the GUI.

                Resetting does not fix a refusal coming from the cloud; it only clears
                local state and buys time. `p81ctl` already retries in place, so this is
                a backstop rather than the main lever.
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
        environment.systemPackages = [ perimeter81 p81-reset p81ctl ];

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
                # No ExecStop on purpose. The daemon's own "stop" subcommand never
                # returned gracefully (every stop on record burned the full 8s timeout),
                # and worse, the binary starts a whole daemon unless it is given `ctl`:
                # each stop booted a second agent that registered with the cloud and was
                # then killed without closing its channel. Plain SIGTERM to the cgroup
                # shuts the real daemon down immediately.
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
                        ${pkgs.systemd}/bin/systemctl restart perimeter81-helper-daemon
                        ${optionalString cfg.autoConnect ''
                            # A restart on its own is often not enough to get the
                            # tunnel back; escalate to the full reset, which retries.
                            if ! ${p81ctl}/bin/p81ctl connect \
                                --timeout ${toString cfg.connectTimeoutSec}; then
                                exec ${p81-reset}/bin/p81-reset
                            fi
                        ''}
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
