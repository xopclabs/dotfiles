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
        restartAfterSleep = mkOption {
            type = types.bool;
            default = false;
            description = ''
                After suspend/hibernate, restart perimeter81-helper-daemon so the tunnel
                does not stay half-dead (UI out of sync, no ping through VPN).
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
                ExecStop = "${perimeter81}/bin/p81-helper-daemon stop";
                Restart = "always";
                RestartSec = "5";
                TimeoutStopSec = "90";
                SyslogIdentifier = "perimeter81helper";
                User = "root";
                Group = "root";
                WorkingDirectory = "/";
            };
        };

        environment.etc = mkMerge [
            (mkIf cfg.restartAfterSleep {
                "systemd/system-sleep/p81-resume" = {
                    mode = "0755";
                    source = pkgs.writeShellScript "p81-resume" ''
                        case "$1/$2" in
                            post/*)
                                ${pkgs.systemd}/bin/systemctl restart perimeter81-helper-daemon || true
                                ;;
                        esac
                    '';
                };
            })
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
