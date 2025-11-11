{ config, pkgs, inputs, ... }:

{
    networking = {
        # Static ip
        useDHCP = false;
            interfaces.ens18 = {
            useDHCP = false;
            ipv4.addresses = [
                {
                    address = config.metadata.network.ipv4;
                    prefixLength = 24;
                }
            ];
        };
        defaultGateway = config.metadata.network.defaultGateway;
        nameservers = [ "127.0.0.1" "1.1.1.1" ];
        
        networkmanager = {
            enable = true;
            dns = "default";
        };
    };
}
