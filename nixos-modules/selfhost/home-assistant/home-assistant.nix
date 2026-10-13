{ config, lib, ... }:

with lib;
let
    cfg = config.homelab.home-assistant;
in
{
    imports = [
        ./setup/onboarding.nix
        ./setup/provisioning.nix
        ./air-conditioner/air-conditioner.nix
        ./zigbee2mqtt.nix
        ./mosquitto.nix
    ];

    options.homelab.home-assistant = {
        enable = mkEnableOption "local Home Assistant stack";
        coordinator = mkOption {
            type = types.str;
            default = "/dev/serial/by-id/usb-SONOFF_SONOFF_Dongle_Plus_MG24_b633be8c75f5ef118936a0a29ed47d52-if00-port0";
            description = "Stable /dev/serial/by-id path for the Zigbee coordinator.";
        };
        subdomain = mkOption {
            type = types.str;
            default = "home.laptop.remote";
            description = "Private Home Assistant subdomain.";
        };
        lanInterface = mkOption {
            type = types.str;
            default = "wlp2s0";
            description = "Interface accepting private LAN access.";
        };
        lanSubnet = mkOption {
            type = types.str;
            default = "192.168.1.0/24";
            description = "Trusted IPv4 LAN subnet; IPv6 ingress remains closed.";
        };
        country = mkOption {
            type = types.strMatching "[A-Z]{2}";
            default = "REDACTED_COUNTRY";
            description = "Home Assistant country (ISO 3166-1 alpha-2).";
        };
    };

    config = mkIf cfg.enable {
        services.home-assistant = {
            enable = true;
            extraComponents = [ "default_config" "mqtt" "met" ];
            config = {
                default_config = { };
                homeassistant = {
                    unit_system = "metric";
                    country = cfg.country;
                };
                automation = "!include automations.yaml";
                script = "!include scripts.yaml";
                scene = "!include scenes.yaml";
            };
        };

        # Only initialize missing files; UI edits survive service starts/rebuilds.
        systemd.services.home-assistant = {
            after = [ "mosquitto.service" ];
            wants = [ "mosquitto.service" ];
            preStart = mkBefore ''
                for file in automations.yaml scenes.yaml; do
                    if [ ! -e "$file" ]; then printf '[]\n' > "$file"; fi
                done
                if [ ! -e scripts.yaml ]; then printf '{}\n' > scripts.yaml; fi
            '';
        };

        assertions = [ {
            assertion = config.homelab.traefik.enable;
            message = "home-assistant requires local homelab.traefik.enable.";
        } ];

        homelab.traefik.routes = [ {
            name = "home-assistant";
            subdomain = cfg.subdomain;
            backendUrl = "http://127.0.0.1:8123";
            middlewares = [ "default-headers" "https-redirect" "home-assistant-private" ];
            wildcardCert = true;
        } ];
        services.traefik.dynamicConfigOptions.http.middlewares.home-assistant-private.ipAllowList.sourceRange = [
            cfg.lanSubnet "127.0.0.1/32"
        ];

        # Insert before normal accepts: even globally opened proxy ports must not
        # admit public IPv4 or IPv6 traffic to this private-only host.
        networking.firewall.extraCommands = ''
            iptables -I nixos-fw 1 -p tcp -m multiport --dports 80,443,8123 -j DROP
            iptables -I nixos-fw 1 -i ${escapeShellArg cfg.lanInterface} -s ${escapeShellArg cfg.lanSubnet} -p tcp -m multiport --dports 80,443,8123 -j nixos-fw-accept
            iptables -I nixos-fw 1 -i lo -p tcp -m multiport --dports 80,443,8123 -j nixos-fw-accept
            ip6tables -I nixos-fw 1 -p tcp -m multiport --dports 80,443,8123 -j DROP
            ip6tables -I nixos-fw 1 -i lo -p tcp -m multiport --dports 80,443,8123 -j nixos-fw-accept
        '';
    };
}
