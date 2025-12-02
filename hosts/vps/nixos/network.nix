{ config, pkgs, lib, ... }:

{
    sops.secrets."network/ipv4" = {
        sopsFile = ../../../secrets/hosts/vps.yaml;
    };
    sops.secrets."network/gateway" = {
        sopsFile = ../../../secrets/hosts/vps.yaml;
    };

    sops.templates."ens3.network" = {
        content = ''
            [Match]
            Name=ens3

            [Network]
            Address=${config.sops.placeholder."network/ipv4"}/24
            Gateway=${config.sops.placeholder."network/gateway"}
            DNS=9.9.9.9
            DNS=1.1.1.1
        '';
        path = "/etc/systemd/network/10-ens3.network";
    };

    networking = {
        useDHCP = false;
        useNetworkd = true;
    };

    systemd.network.enable = true;
}
