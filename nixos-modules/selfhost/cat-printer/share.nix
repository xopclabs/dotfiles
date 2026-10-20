{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.cat-printer.share;
    package = pkgs.callPackage ./gateway-package.nix { };
    user = "catprinter-share";
    chain = "catprinter-share-egress";
    printerSocket = "/run/catprinter-share/printer.sock";
    tunnelUnit = "wireguard-${cfg.relayInterface}.service";
in
{
    options.homelab.cat-printer.share = {
        enable = mkEnableOption "public Catprinter gateway beside the local printer";
        ingress = {
            enable = mkEnableOption "public HTTPS ingress to a Catprinter gateway";
            subdomain = mkOption {
                type = types.str;
                default = "catprinter";
            };
        };
        expiresAt = mkOption {
            type = types.ints.positive;
            description = "Absolute Unix expiry timestamp; restarting does not extend sharing.";
        };
        relayAddress = mkOption {
            type = types.strMatching "[0-9.]+";
            description = "Gateway tunnel address; local on the printer host, remote on the ingress host.";
        };
        ingressAddress = mkOption {
            type = types.strMatching "[0-9.]+";
            description = "Trusted HTTPS proxy's tunnel address.";
        };
        relayInterface = mkOption {
            type = types.strMatching "[a-zA-Z0-9_.-]+";
            description = "Existing WireGuard interface carrying public ingress.";
        };
        relayPort = mkOption {
            type = types.port;
            default = 18858;
        };
    };

    config = mkMerge [
        (mkIf cfg.ingress.enable {
            assertions = [ {
                assertion = config.homelab.traefik.enable;
                message = "cat-printer.share.ingress requires traefik.enable.";
            } ];
            homelab.traefik.routes = [ {
                name = "catprinter-share";
                subdomain = cfg.ingress.subdomain;
                backendUrl = "http://${cfg.relayAddress}:${toString cfg.relayPort}";
            } ];
        })
        (mkIf cfg.enable {
            assertions = [ {
                assertion = config.homelab.cat-printer.enable;
                message = "cat-printer.share requires cat-printer.enable.";
            } {
                assertion = hasAttr cfg.relayInterface config.networking.wireguard.interfaces;
                message = "cat-printer.share.relayInterface must name an existing WireGuard interface.";
            } ];
            users.groups.${user} = { };
            users.users.${user} = {
                isSystemUser = true;
                group = user;
            };
            # Only the gateway group can use the public backend; private TCP requests
            # never acquire public metadata privileges through a supplied header.
            systemd.sockets.cat-printer = {
                listenStreams = [ printerSocket ];
                socketConfig = {
                    SocketMode = "0660";
                    SocketGroup = user;
                    DirectoryMode = "0755";
                    RemoveOnStop = true;
                };
            };
            systemd.services.catprinter-share = {
                description = "Expiring public printer gateway";
                wantedBy = [ "multi-user.target" ];
                requires = [ "firewall.service" tunnelUnit "cat-printer.socket" ];
                after = [ "firewall.service" tunnelUnit "cat-printer.socket" ];
                partOf = [ "firewall.service" tunnelUnit ];
                serviceConfig = {
                    ExecStart = "${package}/bin/catprinter-share --listen-address ${cfg.relayAddress} --port ${toString cfg.relayPort} --printer-socket ${printerSocket} --expires-at ${toString cfg.expiresAt} --trusted-proxy ${cfg.ingressAddress}";
                    User = user;
                    Group = user;
                    Restart = "on-failure";
                    RestartSec = 5;
                    NoNewPrivileges = true;
                    PrivateTmp = true;
                    PrivateDevices = true;
                    ProtectSystem = "strict";
                    ProtectHome = true;
                    ProtectKernelTunables = true;
                    ProtectKernelModules = true;
                    ProtectControlGroups = true;
                    ProtectClock = true;
                    RestrictNamespaces = true;
                    SystemCallArchitectures = "native";
                    LockPersonality = true;
                    RestrictSUIDSGID = true;
                    RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" ];
                    CapabilityBoundingSet = "";
                    IPAddressDeny = "any";
                    IPAddressAllow = [ cfg.ingressAddress ];
                    LimitCORE = 0;
                    MemoryMax = "128M";
                    TasksMax = 32;
                    UMask = "0077";
                };
            };
            # The backend uses a Unix socket. No new outbound IP connections are needed.
            networking.firewall.extraCommands = mkAfter ''
                iptables-restore --noflush <<'RULES'
                *filter
                :${chain} - [0:0]
                -F ${chain}
                -A ${chain} -m conntrack --ctstate ESTABLISHED -j ACCEPT
                -A ${chain} -j REJECT
                COMMIT
                RULES
                iptables -C OUTPUT -m owner --uid-owner ${user} -j ${chain} 2>/dev/null || iptables -I OUTPUT 1 -m owner --uid-owner ${user} -j ${chain}
                ip6tables -C OUTPUT -m owner --uid-owner ${user} -j REJECT 2>/dev/null || ip6tables -I OUTPUT 1 -m owner --uid-owner ${user} -j REJECT
                iptables -I nixos-fw 1 -i ${cfg.relayInterface} -s ${cfg.ingressAddress} -d ${cfg.relayAddress} -p tcp --dport ${toString cfg.relayPort} -j nixos-fw-accept
            '';
            networking.firewall.extraStopCommands = ''
                iptables -D OUTPUT -m owner --uid-owner ${user} -j ${chain} 2>/dev/null || true
                iptables -F ${chain} 2>/dev/null || true
                iptables -X ${chain} 2>/dev/null || true
                ip6tables -D OUTPUT -m owner --uid-owner ${user} -j REJECT 2>/dev/null || true
            '';
        })
    ];
}
