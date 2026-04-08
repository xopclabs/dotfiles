{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.desktop.p81;
    perimeter81-unwrapped = pkgs.callPackage ./package.nix {};
    perimeter81 = pkgs.callPackage ./fhsenv.nix { inherit perimeter81-unwrapped; };
in
{
    options.desktop.p81 = {
        enable = mkEnableOption "Perimeter81 corporate VPN support";
    };

    config = mkIf cfg.enable {
        environment.systemPackages = [ perimeter81 ];

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
                SyslogIdentifier = "perimeter81helper";
                User = "root";
                Group = "root";
                WorkingDirectory = "/";
            };
        };
    };
}
