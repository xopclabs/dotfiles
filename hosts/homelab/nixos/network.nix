{ config, pkgs, inputs, ... }:

{
    networking = {
        # Static ip
        useDHCP = false;
            interfaces.ens18 = {
            useDHCP = false;
            ipv4.addresses = [{
                    address = "192.168.254.10";
                    prefixLength = 24;
                }];
        };
        defaultGateway = "192.168.254.1";
        nameservers = [ "127.0.0.1" "1.1.1.1" ];
        
        networkmanager = {
            enable = true;
            dns = "default";
        };
    };
}
