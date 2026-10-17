{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.cat-printer;
    network = config.metadata.network;
    package = pkgs.callPackage ./package.nix { };
    privateNetworks = [ "127.0.0.1/32" "192.168.0.0/16" "10.0.0.0/8" "172.16.0.0/12" ];
    mkPrivateRoute = name: subdomain: {
        inherit name subdomain;
        backendUrl = "http://127.0.0.1:${toString cfg.port}";
        middlewares = [ "default-headers" "https-redirect" "cat-printer-private" "cat-printer-limit" ];
        wildcardCert = true;
    };
in
{
    options.homelab.cat-printer = {
        enable = mkEnableOption "private MX10 printer web UI and API";
        subdomain = mkOption {
            type = types.str;
            default = "catprinter.laptop.remote";
            description = "Private HTTPS subdomain for the printer web UI and API; no public alias is created.";
        };
        lanAccess = {
            enable = mkEnableOption "direct HTTP access from the trusted LAN";
        };
        deviceAddress = mkOption {
            type = types.strMatching "([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}";
            description = "Bluetooth address of the single MX10 owned by this service.";
        };
        adapter = mkOption {
            type = types.strMatching "hci[0-9]+";
            default = "hci0";
            description = "BlueZ controller used by the printer worker.";
        };
        port = mkOption {
            type = types.port;
            default = 8858;
            description = "HTTP API port, loopback-only unless lanAccess is enabled.";
        };
        allowedNetworks = mkOption {
            type = types.listOf (types.strMatching "[0-9.]+/[0-9]+");
            default = privateNetworks;
            description = "Private IPv4 source networks allowed by the unauthenticated Traefik route; IPv6 ingress remains closed.";
        };
        vpnInterfaces = mkOption {
            type = types.listOf (types.strMatching "[a-zA-Z0-9_.-]+");
            default = [ ];
            description = "VPN interfaces allowed to reach HTTPS despite the laptop's LAN-only proxy firewall guard.";
        };
    };

    config = mkIf cfg.enable {
        assertions = [ {
            assertion = config.homelab.traefik.enable;
            message = "cat-printer requires local homelab.traefik.enable for private HTTPS ingress.";
        } ];

        hardware.bluetooth = {
            enable = true;
            powerOnBoot = true;
        };

        systemd.services.cat-printer = {
            description = "MX10 printer web UI, API and BLE keepalive";
            wantedBy = [ "multi-user.target" ];
            wants = [ "bluetooth.service" ];
            after = [ "bluetooth.service" "network.target" ];
            serviceConfig = {
                ExecStart = "${lib.getExe package} --address ${cfg.deviceAddress} --adapter ${cfg.adapter} --port ${toString cfg.port} --listen-address ${if cfg.lanAccess.enable then "0.0.0.0" else "127.0.0.1"}";
                DynamicUser = true;
                StateDirectory = "cat-printer";
                StateDirectoryMode = "0700";
                UMask = "0077";
                Restart = "on-failure";
                RestartSec = 5;
                TimeoutStopSec = 30;
                NoNewPrivileges = true;
                PrivateTmp = true;
                PrivateDevices = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                ProtectKernelTunables = true;
                ProtectKernelModules = true;
                ProtectControlGroups = true;
                ProtectClock = true;
                RestrictSUIDSGID = true;
                RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
                CapabilityBoundingSet = "";
                IPAddressDeny = "any";
                IPAddressAllow = [ "localhost" ] ++ optional cfg.lanAccess.enable network.subnet;
                LimitCORE = 0;
                MemoryMax = "512M";
                TasksMax = 32;
            };
        };

        # Serve the UI and API through the same private HTTPS origin.
        homelab.traefik.routes = [ (mkPrivateRoute "cat-printer" cfg.subdomain) ];
        homelab.glance.services = mkIf config.homelab.glance.enable [ {
            title = "Catprinter";
            subdomain = cfg.subdomain;
            icon = "mdi:printer";
            group = "Services";
        } ];
        services.traefik.dynamicConfigOptions.http.middlewares = {
            cat-printer-private.ipAllowList.sourceRange = cfg.allowedNetworks;
            cat-printer-limit.rateLimit = {
                average = 60;
                burst = 30;
                period = "1m";
            };
        };

        # HA deliberately guards the shared proxy ports at the host firewall.
        # Add only VPN ingress here; HA's own route still rejects VPN clients.
        # mkAfter keeps these insertions ahead of HA's earlier catch-all DROP.
        networking.firewall.extraCommands = mkAfter (concatMapStrings (interface:
            concatMapStrings (network: ''
                iptables -I nixos-fw 1 -i ${escapeShellArg interface} -s ${escapeShellArg network} -p tcp --dport 443 -j nixos-fw-accept
            '') cfg.allowedNetworks
        ) cfg.vpnInterfaces + optionalString cfg.lanAccess.enable ''
            iptables -I nixos-fw 1 -i ${escapeShellArg network.interface} -s ${escapeShellArg network.subnet} -p tcp --dport ${toString cfg.port} -j nixos-fw-accept
        '');
    };
}
