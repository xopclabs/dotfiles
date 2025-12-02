{ config, pkgs, lib, ... }:

{
    sops.secrets."network/ipv4" = {
        sopsFile = ../../../secrets/hosts/vps.yaml;
    };
    sops.secrets."network/gateway" = {
        sopsFile = ../../../secrets/hosts/vps.yaml;
    };

    # Disable default networking - we configure manually
    networking.useDHCP = false;

    # Configure network after sops decrypts secrets
    systemd.services.network-addresses-ens3 = {
        description = "Configure ens3 network from sops secrets";
        after = [ "sops-nix.service" "sys-subsystem-net-devices-ens3.device" ];
        wants = [ "sops-nix.service" ];
        requires = [ "sys-subsystem-net-devices-ens3.device" ];
        before = [ "network.target" ];
        wantedBy = [ "network.target" ];
        serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
        };
        path = [ pkgs.iproute2 ];
        script = ''
            IP=$(cat ${config.sops.secrets."network/ipv4".path})
            GW=$(cat ${config.sops.secrets."network/gateway".path})

            ip link set ens3 up
            ip addr replace "$IP"/24 dev ens3
            ip route replace default via "$GW" dev ens3
        '';
    };

    # Configure DNS
    environment.etc."resolv.conf".text = ''
        nameserver 9.9.9.9
        nameserver 1.1.1.1
    '';

    # Don't wait for network-online (we handle it ourselves)
    systemd.network.wait-online.enable = false;
}
