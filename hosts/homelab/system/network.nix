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
	nameservers = [ "192.168.254.5" "8.8.8.8" ];
	
        networkmanager = {
            enable = true;
            dns = "systemd-resolved";
        };
    };
    services.resolved.enable = true;
}
