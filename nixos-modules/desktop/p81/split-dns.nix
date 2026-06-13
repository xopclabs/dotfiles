{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.desktop.p81.splitDns;
in
{
    options.desktop.p81.splitDns = {
        enable = mkEnableOption ''
            Static split-DNS routing for private zones that are only reachable through the Perimeter81 corporate VPN.
            Queries for the private zone will SERVFAIL when the VPN is down;
            that is by design (there are no public answers).
        '';

        sopsFile = mkOption {
            type = types.path;
            default = ../../../secrets/shared/personal.yaml;
            description = ''
                Path to the SOPS-encrypted YAML file containing the split-DNS
                fragment. The key referenced by `sopsKey` must hold a multiline
                dnsmasq config snippet, e.g.:

                    dnsmasq:
                        split-dns: |
                            server=/internal.example.com/10.0.0.1
            '';
        };

        sopsKey = mkOption {
            type = types.str;
            default = "dnsmasq/split-dns";
            description = ''
                Key within `sopsFile` whose value is written verbatim to
                /etc/dnsmasq.d/split-dns.conf.
            '';
        };
    };

    config = mkIf cfg.enable {
        services.dnsmasq = {
            enable = true;

            settings = {
                listen-address = [ "127.0.0.1" ];
                bind-dynamic = true;

                no-negcache = true;

                conf-dir = "/etc/dnsmasq.d/,*.conf";

                no-hosts = true;
                domain-needed = true;
                bogus-priv = true;
                cache-size = 1000;
            };
        };

        systemd.tmpfiles.rules = [ "d /etc/dnsmasq.d 0755 root root -" ];

        systemd.services.dnsmasq = {
            wants = [ "NetworkManager.service" ];
            after = [ "NetworkManager.service" ];
        };

        sops.secrets.${cfg.sopsKey} = {
            sopsFile = cfg.sopsFile;
            path = "/etc/dnsmasq.d/split-dns.conf";
            mode = "0444";
            restartUnits = [ "dnsmasq.service" ];
        };
    };
}
