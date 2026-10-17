{ config, lib, ... }:

with lib;
let
    cfg = config.homelab.home-assistant;
    network = config.metadata.network;
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
        vpnAccess = mkOption {
            type = types.attrsOf (types.listOf (types.strMatching "[0-9.]+/[0-9]+"));
            default = { };
            description = "Trusted IPv4 HTTPS sources keyed by VPN interface.";
        };
    };

    config = mkIf cfg.enable {
        sops.secrets."smart-home/ha-country".sopsFile = ../../../secrets/shared/selfhost.yaml;
        sops.templates."home-assistant-secrets.yaml" = {
            content = ''
                country: "${config.sops.placeholder."smart-home/ha-country"}"
            '';
            owner = "hass";
            group = "hass";
            mode = "0400";
            restartUnits = [ "home-assistant.service" ];
        };

        services.home-assistant = {
            enable = true;
            extraComponents = [ "default_config" "mqtt" "met" ];
            config = {
                default_config = { };
                homeassistant = {
                    unit_system = "metric";
                    country = "!secret country";
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
                secrets=${escapeShellArg config.sops.templates."home-assistant-secrets.yaml".path}
                if [ -e secrets.yaml ] || [ -L secrets.yaml ]; then
                    if [ "$(readlink secrets.yaml || true)" != "$secrets" ]; then
                        echo "Refusing to replace unmanaged HA secrets.yaml; migrate its entries into SOPS first" >&2
                        exit 1
                    fi
                fi
                ln -sfn "$secrets" secrets.yaml
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
            network.subnet "127.0.0.1/32"
        ] ++ concatLists (attrValues cfg.vpnAccess);

        # Insert before normal accepts so globally opened proxy ports remain private.
        networking.firewall.extraCommands = ''
            iptables -I nixos-fw 1 -p tcp -m multiport --dports 80,443,8123 -j DROP
            iptables -I nixos-fw 1 -i ${escapeShellArg network.interface} -s ${escapeShellArg network.subnet} -p tcp -m multiport --dports 80,443,8123 -j nixos-fw-accept
            iptables -I nixos-fw 1 -i lo -p tcp -m multiport --dports 80,443,8123 -j nixos-fw-accept
            ${concatStrings (mapAttrsToList (interface: networks:
                concatMapStrings (network: ''
                    iptables -I nixos-fw 1 -i ${escapeShellArg interface} -s ${escapeShellArg network} -p tcp --dport 443 -j nixos-fw-accept
                '') networks
            ) cfg.vpnAccess)}
            ip6tables -I nixos-fw 1 -p tcp -m multiport --dports 80,443,8123 -j DROP
            ip6tables -I nixos-fw 1 -i lo -p tcp -m multiport --dports 80,443,8123 -j nixos-fw-accept
        '';
    };
}
